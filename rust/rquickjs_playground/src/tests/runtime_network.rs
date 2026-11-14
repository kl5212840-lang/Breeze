use crate::web_runtime::{
    configure_http_client, current_http_client_config, set_http_requests_blocked,
};
use crate::{AsyncHostRuntime, HttpClientConfig};
use serde_json::{Value, json};
use std::net::TcpListener;
use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
    mpsc,
};
use std::thread;
use std::time::Duration;
use tiny_http::{Response, Server};

// Only an origin server is opened. The proxy address is a closed local port.
struct LocalOrigin {
    url: String,
    requests: Arc<AtomicUsize>,
    stop: mpsc::Sender<()>,
    worker: Option<thread::JoinHandle<()>>,
}

impl LocalOrigin {
    fn new() -> Self {
        let server = Server::http("127.0.0.1:0").unwrap();
        let url = format!("http://{}", server.server_addr());
        let requests = Arc::new(AtomicUsize::new(0));
        let observed = Arc::clone(&requests);
        let (stop, rx) = mpsc::channel();
        let worker = thread::spawn(move || {
            while rx.try_recv().is_err() {
                if let Some(mut request) = server.recv_timeout(Duration::from_millis(50)).unwrap() {
                    observed.fetch_add(1, Ordering::SeqCst);
                    let mut body = Vec::new();
                    request.as_reader().read_to_end(&mut body).unwrap();
                    let response = if request.url() == "/post" {
                        assert_eq!(request.method().as_str(), "POST");
                        assert_eq!(body, vec![0, 1, 127, 128, 255]);
                        body
                    } else {
                        vec![0, 1, 127, 128, 255]
                    };
                    request.respond(Response::from_data(response)).unwrap();
                }
            }
        });
        Self {
            url,
            requests,
            stop,
            worker: Some(worker),
        }
    }
}

impl Drop for LocalOrigin {
    fn drop(&mut self) {
        let _ = self.stop.send(());
        if let Some(worker) = self.worker.take() {
            worker.join().unwrap();
        }
    }
}

struct GlobalConfigGuard(HttpClientConfig);
impl Drop for GlobalConfigGuard {
    fn drop(&mut self) {
        configure_http_client(self.0.clone()).unwrap();
        set_http_requests_blocked(false);
    }
}

fn fetch_script(url: &str) -> String {
    format!(
        r#"(async () => {{
        try {{
            const result = await fetch({url:?});
            return JSON.stringify({{ok: true, bytes: Array.from(new Uint8Array(await result.arrayBuffer()))}});
        }} catch (_) {{ return JSON.stringify({{ok: false}}); }}
    }})()"#
    )
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn runtime_network_routes_are_immutable_and_fail_closed() {
    let origin = LocalOrigin::new();
    let previous = current_http_client_config();
    let _restore = GlobalConfigGuard(previous);
    let config = HttpClientConfig {
        use_http_proxy: false,
        use_socks5_proxy: false,
        allow_private_network: true,
        ..Default::default()
    };
    configure_http_client(config.clone()).unwrap();
    // This runtime uses the legacy API: it must retain its creation-time route.
    let direct = AsyncHostRuntime::new("network-snapshot").unwrap();
    let reserved = TcpListener::bind("127.0.0.1:0").unwrap();
    let bad_proxy = format!("http://{}", reserved.local_addr().unwrap());
    drop(reserved);
    let bad = AsyncHostRuntime::builder("network-explicit-bad")
        .http_config(config.clone())
        .network_proxy(&bad_proxy)
        .build()
        .unwrap();
    configure_http_client(config.clone().with_network_proxy(Some(&bad_proxy)).unwrap()).unwrap();
    let inherited_bad = AsyncHostRuntime::new("network-new-global-snapshot").unwrap();
    let system = AsyncHostRuntime::builder("network-explicit-system")
        .network_proxy("")
        .build()
        .unwrap();
    let script = fetch_script(&format!("{}/binary", origin.url));
    // Requests overlap on the global multi-thread I/O runtime, including after
    // the global default changes. Bad routes must never reach the origin.
    for _ in 0..8 {
        let direct_task = direct.spawn(&script).unwrap();
        let bad_task = bad.spawn(&script).unwrap();
        let (good, rejected) = tokio::join!(direct_task.wait_async(), bad_task.wait_async());
        let good: Value = serde_json::from_str(&good.unwrap()).unwrap();
        assert_eq!(good["bytes"], json!([0, 1, 127, 128, 255]));
        let rejected: Value = serde_json::from_str(&rejected.unwrap()).unwrap();
        assert_eq!(rejected["ok"], false);
    }
    assert_eq!(origin.requests.load(Ordering::SeqCst), 8);
    let failed: Value = serde_json::from_str(
        &inherited_bad
            .spawn(&script)
            .unwrap()
            .wait_async()
            .await
            .unwrap(),
    )
    .unwrap();
    assert_eq!(failed["ok"], false);
    let system_result: Value =
        serde_json::from_str(&system.spawn(&script).unwrap().wait_async().await.unwrap()).unwrap();
    assert_eq!(system_result["ok"], true);

    let post = format!(
        r#"(async () => {{
        const response = await fetch({:?}, {{method: 'POST', body: new Uint8Array([0,1,127,128,255])}});
        return JSON.stringify(Array.from(new Uint8Array(await response.arrayBuffer())));
    }})()"#,
        format!("{}/post", origin.url)
    );
    let posted: Value =
        serde_json::from_str(&direct.spawn(post).unwrap().wait_async().await.unwrap()).unwrap();
    assert_eq!(posted, json!([0, 1, 127, 128, 255]));

    let bundle = r#"module.exports = {fetchImageBytes: async ({url}) => {
        const r = await fetch(url);
        return new Uint8Array(await r.arrayBuffer());
    }, probe: async ({url}) => {try {await fetch(url); return true;} catch (_) {return false;}}};"#;
    let args = json!([{"url": format!("{}/binary", origin.url)}]);
    direct.bundle_load("plugin", bundle).await.unwrap();
    assert_eq!(
        direct
            .bundle_call_bytes("plugin", "fetchImageBytes", &args)
            .await
            .unwrap(),
        vec![0, 1, 127, 128, 255]
    );
    assert_eq!(
        direct
            .bundle_call_once_bytes(bundle, "fetchImageBytes", &args)
            .await
            .unwrap(),
        vec![0, 1, 127, 128, 255]
    );
    assert_eq!(
        bad.bundle_call_once(bundle, "probe", &args).await.unwrap(),
        false
    );
    assert_eq!(origin.requests.load(Ordering::SeqCst), 12);

    // The dynamic request-blocking middleware remains effective on pooled clients.
    set_http_requests_blocked(true);
    let blocked: Value =
        serde_json::from_str(&direct.spawn(&script).unwrap().wait_async().await.unwrap()).unwrap();
    assert_eq!(blocked["ok"], false);
    assert_eq!(origin.requests.load(Ordering::SeqCst), 12);
    set_http_requests_blocked(false);

    // Debug bundle URLs are loaded by the host, using this same client.
    assert_eq!(
        direct
            .http_client()
            .get(format!("{}/binary", origin.url))
            .send()
            .await
            .unwrap()
            .bytes()
            .await
            .unwrap()
            .as_ref(),
        &[0, 1, 127, 128, 255]
    );
    assert!(
        bad.http_client()
            .get(format!("{}/binary", origin.url))
            .send()
            .await
            .is_err()
    );
    assert_eq!(origin.requests.load(Ordering::SeqCst), 13);
}

/// Exercises a real, already-built Axios plugin without installing dependencies
/// or contacting its site. The fixture path is explicit and optional for CI.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
#[ignore = "requires BREEZE_AXIOS_PLUGIN_FIXTURE pointing to a local Bika CJS"]
async fn runtime_network_real_axios_image_fixture() {
    let path = std::env::var("BREEZE_AXIOS_PLUGIN_FIXTURE").expect("local fixture path required");
    let source = std::fs::read_to_string(path).unwrap();
    let origin = LocalOrigin::new();
    let config = HttpClientConfig {
        allow_private_network: true,
        ..Default::default()
    };
    let direct = AsyncHostRuntime::builder("axios-system")
        .http_config(config.clone())
        .network_proxy("")
        .build()
        .unwrap();
    let reserved = TcpListener::bind("127.0.0.1:0").unwrap();
    let proxy = format!("http://{}", reserved.local_addr().unwrap());
    drop(reserved);
    let bad = AsyncHostRuntime::builder("axios-bad-proxy")
        .http_config(config)
        .network_proxy(proxy)
        .build()
        .unwrap();
    let args = json!([{"url": format!("{}/binary", origin.url), "timeoutMs": 2000}]);
    direct.bundle_load("axios-plugin", &source).await.unwrap();
    assert_eq!(
        direct
            .bundle_call_bytes("axios-plugin", "fetchImageBytes", &args)
            .await
            .unwrap(),
        vec![0, 1, 127, 128, 255]
    );
    assert_eq!(
        direct
            .bundle_call_once_bytes(&source, "fetchImageBytes", &args)
            .await
            .unwrap(),
        vec![0, 1, 127, 128, 255]
    );
    assert!(
        bad.bundle_call_once_bytes(&source, "fetchImageBytes", &args)
            .await
            .is_err()
    );
    assert_eq!(origin.requests.load(Ordering::SeqCst), 2);
}

#[test]
fn runtime_network_proxy_validation_rejects_ambiguous_routes() {
    for proxy in [
        "ftp://localhost:1234",
        "http://user:pass@localhost:1234",
        "socks5://localhost",
        "http://localhost:1234/path",
    ] {
        assert!(
            HttpClientConfig::default()
                .with_network_proxy(Some(proxy))
                .is_err()
        );
    }
    assert!(
        HttpClientConfig::default()
            .with_network_proxy(Some("http://localhost:80"))
            .is_ok()
    );
}

#[test]
fn runtime_network_https_proxy_preserves_scheme_security_and_route_isolation() {
    let previous = HttpClientConfig {
        use_socks5_proxy: true,
        socks5_proxy: Some("socks5://127.0.0.1:1080".to_string()),
        disable_tls_verify: false,
        allow_private_network: false,
        ..Default::default()
    };
    let proxy = previous
        .clone()
        .with_network_proxy(Some("https://localhost:8443"))
        .expect("HTTPS proxy accepted for an explicit runtime route");
    assert!(proxy.use_http_proxy && !proxy.use_socks5_proxy);
    assert_eq!(proxy.http_proxy.as_deref(), Some("https://localhost:8443/"));
    assert!(proxy.socks5_proxy.is_none());
    assert_eq!(proxy.disable_tls_verify, previous.disable_tls_verify);
    assert_eq!(proxy.allow_private_network, previous.allow_private_network);
    assert!(crate::build_http_client(&proxy).is_ok());
    assert!(previous.use_socks5_proxy && previous.http_proxy.is_none());
    let default_port = previous
        .clone()
        .with_network_proxy(Some("https://localhost"))
        .expect("HTTPS proxy default port remains supported");
    assert!(default_port.use_http_proxy && !default_port.use_socks5_proxy);
    let direct = proxy
        .with_network_proxy(Some(""))
        .expect("explicit system route clears the HTTPS proxy");
    assert!(!direct.use_http_proxy && !direct.use_socks5_proxy);
    assert!(direct.http_proxy.is_none() && direct.socks5_proxy.is_none());
}

struct LocalRedirectOrigin {
    url: String,
    redirects: Arc<AtomicUsize>,
    targets: Arc<AtomicUsize>,
    cookies: Arc<AtomicUsize>,
    stop: mpsc::Sender<()>,
    worker: Option<thread::JoinHandle<()>>,
}

impl LocalRedirectOrigin {
    fn new() -> Self {
        let server = Server::http("127.0.0.1:0").unwrap();
        let url = format!("http://{}", server.server_addr());
        let redirects = Arc::new(AtomicUsize::new(0));
        let targets = Arc::new(AtomicUsize::new(0));
        let cookies = Arc::new(AtomicUsize::new(0));
        let observed_redirects = Arc::clone(&redirects);
        let observed_targets = Arc::clone(&targets);
        let observed_cookies = Arc::clone(&cookies);
        let (stop, rx) = mpsc::channel();
        let worker = thread::spawn(move || {
            while rx.try_recv().is_err() {
                if let Some(request) = server.recv_timeout(Duration::from_millis(50)).unwrap() {
                    if request
                        .headers()
                        .iter()
                        .any(|header| header.field.equiv("Cookie"))
                    {
                        observed_cookies.fetch_add(1, Ordering::SeqCst);
                    }
                    if request.url() == "/redirect" {
                        observed_redirects.fetch_add(1, Ordering::SeqCst);
                        request
                            .respond(
                                Response::from_string("redirect body")
                                    .with_status_code(302)
                                    .with_header(
                                        tiny_http::Header::from_bytes(
                                            "Location",
                                            "/target?secret=do-not-include-in-errors",
                                        )
                                        .unwrap(),
                                    )
                                    .with_header(
                                        tiny_http::Header::from_bytes(
                                            "Set-Cookie",
                                            "redirect_session=fixture; Path=/",
                                        )
                                        .unwrap(),
                                    ),
                            )
                            .unwrap();
                    } else if request.url().starts_with("/target?") {
                        observed_targets.fetch_add(1, Ordering::SeqCst);
                        request
                            .respond(Response::from_string("target body"))
                            .unwrap();
                    } else {
                        request
                            .respond(Response::from_string("unknown").with_status_code(404))
                            .unwrap();
                    }
                }
            }
        });
        Self {
            url,
            redirects,
            targets,
            cookies,
            stop,
            worker: Some(worker),
        }
    }
}

impl Drop for LocalRedirectOrigin {
    fn drop(&mut self) {
        let _ = self.stop.send(());
        if let Some(worker) = self.worker.take() {
            worker.join().unwrap();
        }
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn runtime_fetch_redirect_policy_is_per_request_and_legacy_compatible() {
    let origin = LocalRedirectOrigin::new();
    let runtime = AsyncHostRuntime::builder("fetch-per-request-redirect")
        .http_config(HttpClientConfig {
            use_http_proxy: false,
            use_socks5_proxy: false,
            allow_private_network: true,
            ..Default::default()
        })
        .network_proxy("")
        .build()
        .unwrap();
    let url = format!("{}/redirect", origin.url);
    let probe = |options: &str| {
        format!(
            r#"(async () => {{
            try {{
                const response = await fetch({url:?}, {options});
                return JSON.stringify({{status: response.status, url: response.url,
                    location: response.headers.get('location'), body: await response.text()}});
            }} catch (error) {{
                return JSON.stringify({{rejected: true, typeError: error instanceof TypeError,
                    message: String(error.message)}});
            }}
        }})()"#
        )
    };
    let followed: Value = serde_json::from_str(
        &runtime
            .spawn(probe("{}"))
            .unwrap()
            .wait_async()
            .await
            .unwrap(),
    )
    .unwrap();
    assert_eq!(followed["status"], 200);
    assert_eq!(followed["body"], "target body");
    assert_eq!(origin.targets.load(Ordering::SeqCst), 1);

    let rejected: Value = serde_json::from_str(
        &runtime
            .spawn(probe("{redirect: 'error', credentials: 'omit'}"))
            .unwrap()
            .wait_async()
            .await
            .unwrap(),
    )
    .unwrap();
    assert_eq!(rejected["rejected"], true);
    assert_eq!(rejected["typeError"], true);
    assert_eq!(
        rejected["message"],
        "HTTP redirect blocked by request policy"
    );
    assert_eq!(origin.redirects.load(Ordering::SeqCst), 2);
    assert_eq!(
        origin.targets.load(Ordering::SeqCst),
        1,
        "error policy must never send a request to Location"
    );

    let manual: Value = serde_json::from_str(
        &runtime
            .spawn(probe("{redirect: 'manual', credentials: 'omit'}"))
            .unwrap()
            .wait_async()
            .await
            .unwrap(),
    )
    .unwrap();
    assert_eq!(manual["status"], 302);
    assert_eq!(manual["url"], url);
    assert_eq!(
        manual["location"],
        "/target?secret=do-not-include-in-errors"
    );
    assert_eq!(manual["body"], "redirect body");
    assert_eq!(origin.redirects.load(Ordering::SeqCst), 3);
    assert_eq!(origin.targets.load(Ordering::SeqCst), 1);

    // The internal bridge is also exposed to older installed polyfills.
    let legacy = format!(
        r#"(async () => {{
        const result = JSON.parse(await __http_request_promise('GET', {url:?}, '{{}}', null, null));
        if (result.nativeBufferId != null) __native_buffer_free(result.nativeBufferId);
        return JSON.stringify({{ok: result.ok, status: result.status, url: result.url}});
    }})()"#
    );
    let legacy: Value =
        serde_json::from_str(&runtime.spawn(legacy).unwrap().wait_async().await.unwrap()).unwrap();
    assert_eq!(legacy["ok"], true);
    assert_eq!(legacy["status"], 200);
    assert_eq!(origin.targets.load(Ordering::SeqCst), 2);
    let followed_again: Value = serde_json::from_str(
        &runtime
            .spawn(probe("{redirect: 'follow'}"))
            .unwrap()
            .wait_async()
            .await
            .unwrap(),
    )
    .unwrap();
    assert_eq!(followed_again["status"], 200);
    assert_eq!(origin.redirects.load(Ordering::SeqCst), 5);
    assert_eq!(origin.targets.load(Ordering::SeqCst), 3);
    assert_eq!(
        origin.cookies.load(Ordering::SeqCst),
        0,
        "the runtime client must not persist Set-Cookie without a configured cookie jar"
    );
}
