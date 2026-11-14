use ::http::Extensions;
use reqwest_middleware::ClientWithMiddleware;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HttpClientConfig {
    pub use_http_proxy: bool,
    pub use_socks5_proxy: bool,
    pub http_proxy: Option<String>,
    pub socks5_proxy: Option<String>,
    pub disable_tls_verify: bool,
    pub allow_private_network: bool,
}

static HTTP_REQUESTS_BLOCKED: std::sync::atomic::AtomicBool =
    std::sync::atomic::AtomicBool::new(false);

pub fn set_http_requests_blocked(blocked: bool) {
    HTTP_REQUESTS_BLOCKED.store(blocked, Ordering::Release);
}

pub fn is_http_requests_blocked() -> bool {
    HTTP_REQUESTS_BLOCKED.load(Ordering::Acquire)
}

#[derive(Debug, Clone, Copy, Default)]
pub struct HttpRequestBlockMiddleware;

#[async_trait::async_trait]
impl reqwest_middleware::Middleware for HttpRequestBlockMiddleware {
    async fn handle(
        &self,
        request: reqwest::Request,
        extensions: &mut Extensions,
        next: reqwest_middleware::Next<'_>,
    ) -> reqwest_middleware::Result<reqwest::Response> {
        if is_http_requests_blocked() {
            return Err(reqwest_middleware::Error::Middleware(anyhow!(crate::tr!(
                "http-requests-blocked"
            ))));
        }

        next.run(request, extensions).await
    }
}

pub fn wrap_http_client(client: Client) -> ClientWithMiddleware {
    reqwest_middleware::ClientBuilder::new(client)
        .with(HttpRequestBlockMiddleware)
        .build()
}

impl Default for HttpClientConfig {
    fn default() -> Self {
        Self {
            use_http_proxy: true,
            use_socks5_proxy: true,
            http_proxy: None,
            socks5_proxy: None,
            disable_tls_verify: false,
            allow_private_network: false,
        }
    }
}

impl HttpClientConfig {
    /// Apply a visit's immutable route to a snapshot, without changing globals.
    /// An empty route disables client proxies; OS VPN/TUN routing still applies.
    pub fn with_network_proxy(mut self, proxy: Option<&str>) -> AnyResult<Self> {
        let Some(proxy) = proxy else { return Ok(self) };
        let proxy = proxy.trim();
        self.use_http_proxy = false;
        self.use_socks5_proxy = false;
        self.http_proxy = None;
        self.socks5_proxy = None;
        if proxy.is_empty() {
            return Ok(self);
        }
        let url = reqwest::Url::parse(proxy).context("invalid runtime network proxy")?;
        if !matches!(url.scheme(), "http" | "https" | "socks5" | "socks5h")
            || url.host_str().is_none()
            || url.port_or_known_default().is_none()
            || !url.username().is_empty()
            || url.password().is_some()
            || !matches!(url.path(), "" | "/")
            || url.query().is_some()
            || url.fragment().is_some()
        {
            return Err(anyhow!("invalid runtime network proxy"));
        }
        if matches!(url.scheme(), "http" | "https") {
            self.use_http_proxy = true;
            self.http_proxy = Some(url.to_string());
        } else {
            self.use_socks5_proxy = true;
            self.socks5_proxy = Some(url.to_string());
        }
        Ok(self)
    }
}

/// Shared by the primary and one-shot contexts of one runtime. Both target
/// checks and I/O use this owned snapshot even after an async thread hop.
pub(crate) struct RuntimeHttpClient {
    pub(crate) config: HttpClientConfig,
    pub(crate) client: ClientWithMiddleware,
    no_redirect_client: OnceLock<AnyResult<ClientWithMiddleware>>,
    observed_domains: Mutex<std::collections::VecDeque<String>>,
}

impl RuntimeHttpClient {
    pub(crate) fn new(config: HttpClientConfig) -> AnyResult<Self> {
        let client = build_http_client_ex(
            &config,
            BuildHttpClientOptions {
                no_proxy: !config.use_http_proxy && !config.use_socks5_proxy,
                ..Default::default()
            },
        )?;
        Ok(Self {
            config,
            client,
            no_redirect_client: OnceLock::new(),
            observed_domains: Mutex::new(std::collections::VecDeque::new()),
        })
    }

    fn client_for_redirect(&self, policy: Option<&str>) -> AnyResult<&ClientWithMiddleware> {
        if !matches!(policy, Some("error" | "manual")) {
            return Ok(&self.client);
        }
        self.no_redirect_client
            .get_or_init(|| {
                build_http_client_ex(
                    &self.config,
                    BuildHttpClientOptions {
                        no_proxy: !self.config.use_http_proxy && !self.config.use_socks5_proxy,
                        follow_redirects: Some(false),
                        ..Default::default()
                    },
                )
            })
            .as_ref()
            .map_err(|error| anyhow!("{error:#}"))
    }

    /// Only host-owned completed HTTP responses can populate this queue.
    /// Observation is best effort and never delays or fails a plugin request.
    fn observe_response(&self, requested: &str, final_url: &str, status: u16) {
        if !(200..300).contains(&status) {
            return;
        }
        let Ok(mut domains) = self.observed_domains.try_lock() else {
            return;
        };
        for host in [requested, final_url]
            .into_iter()
            .filter_map(public_https_domain)
        {
            if domains.contains(&host) {
                continue;
            }
            if domains.len() == 64 {
                domains.pop_front();
            }
            domains.push_back(host);
        }
    }

    pub(crate) fn drain_observed_domains(&self) -> Vec<String> {
        self.observed_domains
            .try_lock()
            .map(|mut domains| domains.drain(..).collect())
            .unwrap_or_default()
    }
}

/// Syntactic public-domain filtering only: no DNS or additional network I/O.
/// IP literals and private/reserved naming namespaces never become routing rules.
fn public_https_domain(value: &str) -> Option<String> {
    let parsed = reqwest::Url::parse(value).ok()?;
    if parsed.scheme() != "https" {
        return None;
    }
    let url::Host::Domain(domain) = parsed.host()? else {
        return None;
    };
    let host = domain.trim_end_matches('.').to_ascii_lowercase();
    if host.len() > 253 || !host.contains('.') || host.parse::<IpAddr>().is_ok() {
        return None;
    }
    if host.split('.').any(|label| {
        label.is_empty()
            || label.len() > 63
            || label.starts_with('-')
            || label.ends_with('-')
            || !label
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'-')
    }) {
        return None;
    }
    for reserved in [
        "localhost",
        "local",
        "internal",
        "intranet",
        "lan",
        "home",
        "home.arpa",
        "arpa",
        "test",
        "invalid",
        "example",
        "onion",
        "example.com",
        "example.org",
        "example.net",
    ] {
        if host == reserved || host.ends_with(&format!(".{reserved}")) {
            return None;
        }
    }
    Some(host)
}

pub(crate) struct HttpClientState {
    config: HttpClientConfig,
}

impl Default for HttpClientState {
    fn default() -> Self {
        Self {
            config: HttpClientConfig::default(),
        }
    }
}

fn http_promise_cancel_senders() -> &'static Mutex<HashMap<u64, oneshot::Sender<()>>> {
    static HTTP_PROMISE_CANCEL_SENDERS: OnceLock<Mutex<HashMap<u64, oneshot::Sender<()>>>> =
        OnceLock::new();
    HTTP_PROMISE_CANCEL_SENDERS.get_or_init(|| Mutex::new(HashMap::new()))
}

/// 当前挂起的 HTTP 取消 sender 数量（用于诊断/测试确认正常完成后被清理）。
pub fn http_promise_cancel_senders_len() -> usize {
    http_promise_cancel_senders()
        .lock()
        .map(|m| m.len())
        .unwrap_or(0)
}

pub(crate) fn http_io_sem() -> &'static Arc<Semaphore> {
    HTTP_IO_SEM.get_or_init(|| Arc::new(Semaphore::new(HTTP_MAX_IN_FLIGHT)))
}

pub(crate) fn cleanup_stale_pending(
    pool: &mut HashMap<u64, PendingTask>,
    dropped_counter: &AtomicU64,
) {
    let now = Instant::now();
    let stale_items: Vec<(u64, PendingTaskMeta, u64)> = pool
        .iter()
        .filter_map(|(id, pending)| {
            if now.duration_since(pending.created_at) > PENDING_TASK_TTL {
                Some((
                    *id,
                    pending.meta.clone(),
                    now.duration_since(pending.created_at).as_millis() as u64,
                ))
            } else {
                None
            }
        })
        .collect();

    for (id, meta, elapsed_ms) in stale_items {
        if let Some(pending) = pool.remove(&id) {
            pending.task.abort();
            dropped_counter.fetch_add(1, Ordering::Relaxed);
            tracing::warn!(
                "cleanup stale pending task: kind={}, id={}, elapsed_ms={}, label={}",
                meta.kind,
                id,
                elapsed_ms,
                meta.label
            );
        }
    }
}

pub(crate) fn cleanup_stale_pending_abort(
    pool: &mut HashMap<u64, PendingAbortTask>,
    dropped_counter: &AtomicU64,
) {
    let now = Instant::now();
    let stale_items: Vec<(u64, PendingAbortTaskMeta, u64)> = pool
        .iter()
        .filter_map(|(id, pending)| {
            if now.duration_since(pending.created_at) > PENDING_TASK_TTL {
                Some((
                    *id,
                    pending.meta.clone(),
                    now.duration_since(pending.created_at).as_millis() as u64,
                ))
            } else {
                None
            }
        })
        .collect();

    for (id, meta, elapsed_ms) in stale_items {
        if let Some(pending) = pool.remove(&id) {
            pending.task.abort();
            dropped_counter.fetch_add(1, Ordering::Relaxed);
            tracing::warn!(
                "cleanup stale pending abort task: kind={}, id={}, elapsed_ms={}, label={}",
                meta.kind,
                id,
                elapsed_ms,
                meta.label
            );
        }
    }
}

fn header_truthy(value: &str) -> bool {
    matches!(
        value.trim().to_ascii_lowercase().as_str(),
        "1" | "true" | "yes" | "on"
    )
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct HostFormDataPlan {
    kind: Option<String>,
    entries: Vec<HostFormDataEntry>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct HostFormDataEntry {
    name: String,
    kind: String,
    value: Option<String>,
    data_b64: Option<String>,
    filename: Option<String>,
    content_type: Option<String>,
}

fn parse_host_formdata_plan(raw_json: &str) -> AnyResult<HostFormDataPlan> {
    let plan = serde_json::from_str::<HostFormDataPlan>(raw_json)
        .context(crate::tr!("failed-to-parse-host-formdata-plan-json"))?;
    if let Some(kind) = &plan.kind {
        if kind != "rquickjs-formdata-v1" {
            return Err(anyhow!(crate::tr!(
                "unsupported-formdata-plan-kind",
                kind = kind
            )));
        }
    }
    Ok(plan)
}

pub(crate) fn decode_host_base64(raw_b64: &str) -> AnyResult<Vec<u8>> {
    let raw = raw_b64.trim();
    BASE64_STANDARD
        .decode(raw)
        .or_else(|_| BASE64_URL_SAFE.decode(raw))
        .context(crate::tr!("failed-to-base64-decode-formdata-field"))
}

fn build_multipart_form(plan: HostFormDataPlan) -> AnyResult<MultipartForm> {
    let mut form = MultipartForm::new();
    for entry in plan.entries {
        if entry.kind.eq_ignore_ascii_case("text") {
            let value = entry
                .value
                .ok_or_else(|| anyhow!(crate::tr!("formdata-text-field-missing-value")))?;
            form = form.text(entry.name, value);
            continue;
        }

        if entry.kind.eq_ignore_ascii_case("binary") {
            let data_b64 = entry
                .data_b64
                .ok_or_else(|| anyhow!(crate::tr!("formdata-binary-field-missing-datab64")))?;
            let bytes = decode_host_base64(&data_b64)?;
            let mut part = MultipartPart::bytes(bytes);
            if let Some(filename) = entry.filename {
                part = part.file_name(filename);
            }
            if let Some(content_type) = entry
                .content_type
                .as_deref()
                .map(str::trim)
                .filter(|v| !v.is_empty())
            {
                part = part.mime_str(content_type).map_err(|e| {
                    anyhow!(crate::tr!(
                        "failed-to-set-formdata-part-content-type",
                        e = e
                    ))
                })?;
            }
            form = form.part(entry.name, part);
            continue;
        }

        return Err(anyhow!(crate::tr!(
            "unsupported-formdata-field-type",
            arg0 = entry.kind
        )));
    }
    Ok(form)
}

fn http_client_state_cell() -> &'static Mutex<HttpClientState> {
    HTTP_CLIENT_STATE.get_or_init(|| Mutex::new(HttpClientState::default()))
}

pub fn configure_http_client(config: HttpClientConfig) -> AnyResult<()> {
    let mut state = http_client_state_cell()
        .lock()
        .map_err(|_| anyhow!(crate::tr!("http-client-state-lock-is-poisoned")))?;
    state.config = config;
    Ok(())
}

pub fn current_http_client_config() -> HttpClientConfig {
    http_client_state_cell()
        .lock()
        .map(|g| g.config.clone())
        .unwrap_or_default()
}

fn normalize_http_proxy_url(raw: &str) -> String {
    let value = raw.trim();
    if value.contains("://") {
        return value.to_string();
    }
    format!("http://{value}")
}

fn normalize_socks5_proxy_url(raw: &str) -> String {
    let value = raw.trim();
    if value.contains("://") {
        return value.to_string();
    }
    format!("socks5h://{value}")
}

/// 创建 `reqwest::Client` 时的额外选项（超时 / 直连 / 重定向 / UA）。
#[derive(Debug, Clone, Default)]
pub struct BuildHttpClientOptions {
    pub no_proxy: bool,
    pub https_only: bool,
    pub timeout: Option<Duration>,
    pub connect_timeout: Option<Duration>,
    pub follow_redirects: Option<bool>,
    pub user_agent: Option<String>,
}

/// 按当前/指定全局配置创建 `reqwest::Client`。
pub fn build_http_client(config: &HttpClientConfig) -> AnyResult<ClientWithMiddleware> {
    build_http_client_ex(config, BuildHttpClientOptions::default())
}

/// 创建 HTTP 客户端（可覆盖直连、超时、重定向、UA）。
pub fn build_http_client_ex(
    config: &HttpClientConfig,
    options: BuildHttpClientOptions,
) -> AnyResult<ClientWithMiddleware> {
    let mut builder = Client::builder()
        .https_only(options.https_only)
        .timeout(options.timeout.unwrap_or(Duration::from_secs(30)));
    if let Some(connect_timeout) = options.connect_timeout {
        builder = builder.connect_timeout(connect_timeout);
    }
    if !options.follow_redirects.unwrap_or(true) {
        builder = builder.redirect(reqwest::redirect::Policy::none());
    }

    if options.no_proxy {
        builder = builder.no_proxy();
    } else if config.use_http_proxy {
        if let Some(proxy_raw) = config.http_proxy.as_deref() {
            let proxy_url = normalize_http_proxy_url(proxy_raw);
            let proxy = Proxy::all(&proxy_url).with_context(|| {
                crate::tr!("failed-to-parse-http-proxy-address", proxy_url = proxy_url)
            })?;
            builder = builder.proxy(proxy);
        } else if config.use_socks5_proxy {
            if let Some(proxy_raw) = config.socks5_proxy.as_deref() {
                let proxy_url = normalize_socks5_proxy_url(proxy_raw);
                let proxy = Proxy::all(&proxy_url).with_context(|| {
                    crate::tr!(
                        "failed-to-parse-socks5-proxy-address",
                        proxy_url = proxy_url
                    )
                })?;
                builder = builder.proxy(proxy);
            }
        }
    } else if config.use_socks5_proxy {
        if let Some(proxy_raw) = config.socks5_proxy.as_deref() {
            let proxy_url = normalize_socks5_proxy_url(proxy_raw);
            let proxy = Proxy::all(&proxy_url).with_context(|| {
                crate::tr!(
                    "failed-to-parse-socks5-proxy-address",
                    proxy_url = proxy_url
                )
            })?;
            builder = builder.proxy(proxy);
        }
    }

    if config.disable_tls_verify {
        builder = builder.danger_accept_invalid_certs(true);
    }
    if let Some(ua) = options.user_agent.as_ref().filter(|s| !s.is_empty()) {
        builder = builder.user_agent(ua);
    }

    let client = builder
        .build()
        .context(crate::tr!("failed-to-create-http-client"))?;
    Ok(wrap_http_client(client))
}

pub(crate) fn http_request_promise<'js>(
    ctx: Ctx<'js>,
    method: String,
    url: String,
    headers_json: String,
    body: Option<String>,
    body_native_buffer_id: Option<u64>,
    redirect: Option<String>,
    http: Arc<RuntimeHttpClient>,
) -> rquickjs::Result<QjsValue<'js>> {
    let id = HTTP_REQ_ID.fetch_add(1, Ordering::Relaxed);
    let (cancel_tx, cancel_rx) = oneshot::channel::<()>();
    {
        let mut senders = http_promise_cancel_senders()
            .lock()
            .expect(&crate::tr!("failed-to-lock-http-promise-cancel-senders"));
        senders.insert(id, cancel_tx);
    }

    // 实际 HTTP 请求放进独立 tokio 任务，由 tokio 的 I/O 驱动直接轮询，
    // 不经过 rquickjs 的 Spawner（那会被 JS 事件泵以固定节奏轮询，导致
    // 分块到达的大响应体逐块慢读）。JS 面只等一个 oneshot 结果。
    // Carry the runtime's client/config as owned data, never thread-local state:
    // this future can resume on a different global-runtime worker after await.
    let cleanup_id = id;
    let work = async move {
        let sem = Arc::clone(http_io_sem());
        let permit = match timeout(Duration::from_secs(15), sem.acquire_owned()).await {
            Ok(Ok(permit)) => permit,
            Ok(Err(_)) => {
                return json!({ "ok": false, "error": crate::tr!("http-concurrency-controller-unavailable") })
                    .to_string();
            }
            Err(_) => {
                return json!({ "ok": false, "error": crate::tr!("timed-out-waiting-for-http-concurrency-permit") })
                    .to_string();
            }
        };

        let result = tokio::select! {
            biased;
            _ = cancel_rx => {
                Ok(json!({
                    "ok": false,
                    "error": crate::tr!("request-was-canceled"),
                    "canceled": true
                })
                .to_string())
            }
            r = http_request_inner_async(method, url, headers_json, body, body_native_buffer_id, redirect, http) => r,
        };

        drop(permit);

        // 请求已结束（成功、失败或被取消），从 map 移除取消 sender，
        // 否则每个完成的请求都会在 http_promise_cancel_senders 里留下
        // 一个永远不会被删除的悬空 sender，长会话内存持续增长。
        http_promise_cancel_senders()
            .lock()
            .expect(&crate::tr!("failed-to-lock-http-promise-cancel-senders"))
            .remove(&cleanup_id);

        match result {
            Ok(payload) => payload,
            Err(error) => json!({ "ok": false, "error": format!("{error:#}") }).to_string(),
        }
    };
    let (result_tx, result_rx) = oneshot::channel::<String>();
    crate::global_runtime().spawn(async move {
        let _ = result_tx.send(work.await);
    });

    // JS 面只等一个 oneshot 结果，不再逐块轮询。
    let future = async move {
        result_rx.await.unwrap_or_else(|_| {
            json!({ "ok": false, "error": crate::tr!("request-execution-cancelled") }).to_string()
        })
    };

    let promise = Promise::wrap_future(&ctx, future)?;
    let obj = promise.into_inner();
    if let Err(e) = obj.set("__hostRequestId", id) {
        http_promise_cancel_senders().lock().unwrap().remove(&id);
        return Err(e);
    }
    Ok(obj.into_value())
}

pub fn http_request_cancel(id: u64) -> String {
    let sender = http_promise_cancel_senders()
        .lock()
        .expect(&crate::tr!("failed-to-lock-http-promise-cancel-senders"))
        .remove(&id);
    let existed = if let Some(tx) = sender {
        let _ = tx.send(());
        HTTP_EVENT_CANCELED.fetch_add(1, Ordering::Relaxed);
        true
    } else {
        false
    };
    json!({ "ok": true, "canceled": existed }).to_string()
}

/// 为什么 HTTP 必须跑在多线程 runtime 上：QJS worker 用的是 current_thread
/// 单线程 runtime，它的事件循环（pump_jobs）以固定节奏轮询 JS 任务，HTTP
/// 响应体分块到达时无法被及时驱动（实测每块 ~50-80ms），几 MB 的 body 会拖到
/// 数秒甚至超时。这里把请求派发到进程级全局多线程 runtime（[`crate::global_runtime`]），
/// body 读取由 tokio 的 I/O 直接驱动，和直连一致。

async fn http_request_inner_async(
    method: String,
    url: String,
    headers_json: String,
    body: Option<String>,
    body_native_buffer_id: Option<u64>,
    redirect: Option<String>,
    http: Arc<RuntimeHttpClient>,
) -> AnyResult<String> {
    let method =
        Method::from_bytes(method.as_bytes()).context(crate::tr!("failed-to-parse-http-method"))?;
    ensure_http_target_allowed(&url, &http.config).await?;
    let mut headers_map = Map::new();
    let headers_value: Value = serde_json::from_str(&headers_json)
        .context(crate::tr!("failed-to-parse-http-headers-json"))?;
    let mut formdata_body = false;
    let mut plain_headers: Vec<(String, String)> = Vec::new();

    let client = http.client_for_redirect(redirect.as_deref())?;
    let mut builder = client.request(method, &url);

    if let Value::Object(obj) = headers_value {
        for (key, value) in obj {
            if let Some(v) = value.as_str() {
                if key.eq_ignore_ascii_case(HTTP_FORMDATA_BODY_HEADER) {
                    formdata_body = header_truthy(v);
                    continue;
                }
                plain_headers.push((key, v.to_string()));
            }
        }
    }

    for (key, value) in plain_headers {
        if formdata_body && key.eq_ignore_ascii_case("content-type") {
            continue;
        }
        builder = builder.header(&key, value);
    }

    if formdata_body {
        let raw_plan =
            body.ok_or_else(|| anyhow!(crate::tr!("formdata-request-missing-body-payload")))?;
        let plan = parse_host_formdata_plan(&raw_plan)?;
        let form = build_multipart_form(plan)?;
        builder = builder.multipart(form);
    } else if let Some(native_buffer_id) = body_native_buffer_id {
        let bytes = native_buffer_take_raw(native_buffer_id).ok_or_else(|| {
            anyhow!(crate::tr!(
                "request-body-nativebufferid-does-not-exist",
                native_buffer_id = native_buffer_id
            ))
        })?;
        builder = builder.body(bytes);
    } else if let Some(content) = body {
        builder = builder.body(content);
    }

    let response = builder
        .send()
        .await
        .context(crate::tr!("failed-to-send-http-request"))?;
    let status = response.status();
    if redirect.as_deref() == Some("error") && status.is_redirection() {
        // Do not expose a possibly sensitive Location or consume its target.
        return Err(anyhow!("HTTP redirect blocked by request policy"));
    }
    let final_url = response.url().to_string();

    for (name, value) in response.headers() {
        let value_text = value
            .to_str()
            .context(crate::tr!("failed-to-parse-http-response-headers"))?
            .to_string();
        headers_map.insert(name.to_string(), Value::String(value_text));
    }

    let body_bytes = response
        .bytes()
        .await
        .context(crate::tr!("failed-to-read-http-response-body-bytes"))?
        .to_vec();

    // Capture only a successfully completed response, never headers/body/secrets.
    http.observe_response(&url, &final_url, status.as_u16());

    let native_buffer_id = NATIVE_BUF_ID.fetch_add(1, Ordering::Relaxed);
    let body_len = body_bytes.len();

    {
        let mut pool = native_pool()
            .lock()
            .expect(&crate::tr!("failed-to-lock-native-buffer-pool"));
        pool.insert(
            native_buffer_id,
            NativeBufferEntry::with_http_response(
                body_bytes,
                NativeBufferHttpResponse {
                    status_code: status.as_u16(),
                    body_length: body_len as u64,
                },
            ),
        );
    }

    Ok(json!({
        "ok": true,
        "status": status.as_u16(),
        "statusText": status.canonical_reason().unwrap_or(""),
        "url": final_url,
        "headers": headers_map,
        "body": "",
        "offloaded": true,
        "nativeBufferId": native_buffer_id,
        "offloadedBytes": body_len
    })
    .to_string())
}

async fn ensure_http_target_allowed(url: &str, config: &HttpClientConfig) -> AnyResult<()> {
    if config.allow_private_network {
        return Ok(());
    }

    let parsed =
        reqwest::Url::parse(url).with_context(|| crate::tr!("failed-to-parse-url", url = url))?;
    let host = parsed
        .host_str()
        .ok_or_else(|| anyhow!(crate::tr!("url-missing-host", url = url)))?
        .trim();

    if host.eq_ignore_ascii_case("localhost") || host.to_ascii_lowercase().ends_with(".localhost") {
        return Err(anyhow!(crate::tr!("blocked-intranet-request", host = host)));
    }

    if let Ok(ip) = host.parse::<IpAddr>() {
        if is_private_or_local_ip(ip) {
            return Err(anyhow!(crate::tr!("blocked-intranet-request", host = host)));
        }
        return Ok(());
    }

    let port = parsed.port_or_known_default().unwrap_or(80);
    let resolved = lookup_host((host, port))
        .await
        .with_context(|| crate::tr!("failed-to-parse-domain", host = host))?;
    for socket in resolved {
        if is_private_or_local_ip(socket.ip()) {
            return Err(anyhow!(crate::tr!("blocked-intranet-request", host = host)));
        }
    }

    Ok(())
}

fn is_private_or_local_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ipv4) => is_private_or_local_ipv4(ipv4),
        IpAddr::V6(ipv6) => is_private_or_local_ipv6(ipv6),
    }
}

fn is_private_or_local_ipv4(ip: Ipv4Addr) -> bool {
    let [a, b, ..] = ip.octets();
    ip.is_loopback()
        || ip.is_private()
        || ip.is_link_local()
        || ip.is_unspecified()
        || (a == 100 && (64..=127).contains(&b))
}

fn is_private_or_local_ipv6(ip: Ipv6Addr) -> bool {
    ip.is_loopback() || ip.is_unspecified() || ip.is_unique_local() || ip.is_unicast_link_local()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn observed_domains_accept_only_public_https_hostnames() {
        assert_eq!(
            public_https_domain("https://CDN.publisher.org./private/path?token=secret#fragment"),
            Some("cdn.publisher.org".into())
        );
        assert_eq!(
            public_https_domain("https://user:secret@images.publisher.org:8443/picture"),
            Some("images.publisher.org".into())
        );
        for value in [
            "http://cdn.publisher.org/video",
            "https://localhost/",
            "https://foo.local/",
            "https://intranet/",
            "https://foo.internal/",
            "https://foo.lan/",
            "https://foo.home.arpa/",
            "https://foo.test/",
            "https://foo.invalid/",
            "https://example.com/",
            "https://sub.example.net/",
            "https://foo.onion/",
            "https://127.0.0.1/",
            "https://8.8.8.8/",
            "https://[::1]/",
            "https://[2606:4700:4700::1111]/",
            "https://bad_label.publisher.org/",
            "not a URL",
        ] {
            assert_eq!(public_https_domain(value), None, "{value}");
        }
    }

    #[tokio::test]
    async fn observed_domains_are_status_gated_host_only_deduplicated_and_drained() {
        let client = RuntimeHttpClient::new(HttpClientConfig::default()).unwrap();
        for status in [199, 301, 404, 500] {
            client.observe_response(
                "https://api.publisher.org/",
                "https://cdn.publisher.org/",
                status,
            );
        }
        assert!(client.drain_observed_domains().is_empty());
        client.observe_response(
            "https://api.publisher.org/path?account=secret",
            "https://cdn.publisher.org/file?token=secret",
            200,
        );
        client.observe_response(
            "https://api.publisher.org/other",
            "https://cdn.publisher.org/other",
            206,
        );
        assert_eq!(
            client.drain_observed_domains(),
            ["api.publisher.org", "cdn.publisher.org"]
        );
        assert!(client.drain_observed_domains().is_empty());
    }

    #[tokio::test]
    async fn observed_domains_are_runtime_owned_and_bounded_without_blocking() {
        let first = RuntimeHttpClient::new(HttpClientConfig::default()).unwrap();
        let second = RuntimeHttpClient::new(HttpClientConfig::default()).unwrap();
        for index in 0..100 {
            let url = format!("https://cdn{index}.publisher.org/private");
            first.observe_response(&url, &url, 200);
        }
        assert!(second.drain_observed_domains().is_empty());
        let domains = first.drain_observed_domains();
        assert_eq!(domains.len(), 64);
        assert_eq!(domains.first().unwrap(), "cdn36.publisher.org");
        assert_eq!(domains.last().unwrap(), "cdn99.publisher.org");
        let lock = first.observed_domains.lock().unwrap();
        // A contended observer cannot hold up successful HTTP completion.
        first.observe_response(
            "https://api.publisher.org/",
            "https://cdn.publisher.org/",
            200,
        );
        assert!(first.drain_observed_domains().is_empty());
        drop(lock);
        first.observe_response(
            "https://api.publisher.org/",
            "https://cdn.publisher.org/",
            200,
        );
        assert_eq!(first.drain_observed_domains().len(), 2);
    }

    #[tokio::test]
    async fn blocked_request_middleware_returns_before_io() {
        let previous = is_http_requests_blocked();
        set_http_requests_blocked(true);
        let client = build_http_client(&HttpClientConfig {
            use_http_proxy: false,
            use_socks5_proxy: false,
            ..Default::default()
        })
        .expect("middleware client should build without network I/O");
        let result = client.get("http://192.0.2.1/").send().await;
        set_http_requests_blocked(previous);

        let error = result.expect_err("blocked request should fail");
        assert!(error.is_middleware());
        assert!(error.to_string().contains("HTTP"));
    }
}
use super::*;
