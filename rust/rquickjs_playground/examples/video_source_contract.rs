//! Runs the shipped bundle in Breeze's real QuickJS host. No browser cookies.
//! Prints only aggregate structure; media addresses and payloads stay local.
use rquickjs_playground::AsyncHostRuntime;
use serde_json::{Value, json};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 4 {
        return Err("usage: video_source_contract BUNDLE FUNCTION ARGS_JSON".into());
    }
    let source = std::fs::read_to_string(&args[1])?;
    let parameters: Value = serde_json::from_str(&args[3])?;
    let host = AsyncHostRuntime::new("video-source-contract")?;
    host.spawn(
        r#"
      globalThis.__contractRequests = [];
      const originalFetch = globalThis.fetch;
      globalThis.fetch = async function(input, options) {
        const entry = {host:new URL(String(input)).host};
        globalThis.__contractRequests.push(entry);
        const started=Date.now();
        try { const result=await originalFetch(input, options);
          entry.status=result.status;return result;
        } catch(error) { entry.category=String(error.name||'Error');throw error;
        } finally { entry.ms=Date.now()-started; }
      };
      'ready'
    "#,
    )?
    .wait_async()
    .await?;
    host.bundle_load("contract", &source).await?;
    let response = host
        .bundle_call("contract", &args[2], &json!([parameters]))
        .await;
    let trace = host
        .spawn("JSON.stringify(globalThis.__contractRequests)")?
        .wait_async()
        .await?;
    let requests: Value = serde_json::from_str(&trace)?;
    let result = match response {
        Ok(result) => result,
        Err(error) => {
            eprintln!("{}", json!({"requests":requests}));
            return Err(error.into());
        }
    };
    let data = result.get("data").unwrap_or(&result);
    let items = data.get("items").and_then(Value::as_array);
    let item = data.get("item").unwrap_or(data);
    let lines = item.get("lines").and_then(Value::as_array);
    let sources = data.get("sources").and_then(Value::as_array);
    let media_hosts: Vec<_> = sources
        .into_iter()
        .flatten()
        .filter_map(|s| {
            url::Url::parse(s.get("url")?.as_str()?)
                .ok()
                .map(|u| u.host_str().unwrap_or("").to_owned())
        })
        .collect();
    println!(
        "{}",
        json!({
            "function":args[2], "items":items.map(Vec::len),
            "categories":data.get("categories").and_then(Value::as_array).map(Vec::len),
            "lines":lines.map(Vec::len),
            "episodes":lines.map(|v| v.iter().filter_map(|l|l.get("episodes").and_then(Value::as_array)).map(Vec::len).sum::<usize>()),
            "lineId":data.get("lineId"),"episodeId":data.get("episodeId"),
            "media_hosts":media_hosts,
            "browser_request":data.get("browserRequest").is_some(),
            "uuid":data.get("uuid"),"version":data.get("version"),
            "requests":requests,
        })
    );
    Ok(())
}
