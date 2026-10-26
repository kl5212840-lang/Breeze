use srcmap_sourcemap::SourceMap;
use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

static REGISTRY: LazyLock<Mutex<HashMap<String, SourceMap>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

pub fn register(name: &str, map_json: &str) -> Result<(), String> {
    let sm = SourceMap::from_json(map_json).map_err(|e| format!("parse sourcemap: {e}"))?;
    REGISTRY
        .lock()
        .map_err(|e| format!("lock: {e}"))?
        .insert(name.to_string(), sm);
    Ok(())
}

pub fn unregister(name: &str) {
    if let Ok(mut maps) = REGISTRY.lock() {
        maps.remove(name);
    }
}
pub fn extract_and_register(name: &str, bundle_source: &str) -> Result<(), String> {
    // A replacement without a source map must not retain the previous version's
    // mappings under the same bundle identity.
    unregister(name);
    let marker = "//# sourceMappingURL=data:application/json;";
    let pos = bundle_source.rfind(marker).ok_or("no inline source map")?;
    let after = &bundle_source[pos + marker.len()..];
    // skip optional charset parameter like "charset=utf-8;"
    let b64_start = after.find("base64,").ok_or("no base64 marker")? + "base64,".len();
    let b64 = after[b64_start..].trim();

    let decoded = base64::Engine::decode(&base64::engine::general_purpose::STANDARD, b64)
        .map_err(|e| format!("base64 decode: {e}"))?;
    let json = std::str::from_utf8(&decoded).map_err(|e| format!("utf8: {e}"))?;
    register(name, json)
}

pub fn look_up(bundle_name: &str, gen_line_1: u32, gen_col_0: u32) -> Option<LookUpResult> {
    let maps = REGISTRY.lock().ok()?;
    // 只查指定 bundle；指定查不到且全局仅一个 map 时用它（单 bundle/测试场景），
    // 多 bundle 下查不到就返回空，不乱指。
    let sm = maps.get(bundle_name).or_else(|| {
        (bundle_name == "__default__" && maps.len() == 1)
            .then(|| maps.values().next())
            .flatten()
    })?;
    for offset in [3u32, 1u32] {
        let sm_line = gen_line_1.saturating_sub(offset);
        // QuickJS column may be off by a few; scan backwards
        for dc in (0..=8).rev() {
            let col = gen_col_0.saturating_sub(dc);
            if let Some(loc) = sm.original_position_for(sm_line, col) {
                let source = sm.source(loc.source).to_string();
                let name = loc.name.and_then(|n| {
                    let s = sm.name(n);
                    if s.is_empty() {
                        None
                    } else {
                        Some(s.to_string())
                    }
                });
                return Some(LookUpResult {
                    source,
                    line: loc.line + 1,
                    column: loc.column,
                    name,
                });
            }
        }
    }
    None
}

pub struct LookUpResult {
    pub source: String,
    pub line: u32,
    pub column: u32,
    pub name: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn named_bundle_maps_never_fall_through_to_another_plugin() {
        let alpha = "__isolation_alpha__";
        let beta = "__isolation_beta__";
        register(
            alpha,
            r#"{"version":3,"sources":["alpha.ts"],"names":[],"mappings":"AAAA"}"#,
        )
        .unwrap();
        register(
            beta,
            r#"{"version":3,"sources":["beta.ts"],"names":[],"mappings":"AAAA"}"#,
        )
        .unwrap();
        assert_eq!(look_up(alpha, 3, 0).unwrap().source, "alpha.ts");
        assert_eq!(look_up(beta, 3, 0).unwrap().source, "beta.ts");
        unregister(alpha);
        assert!(look_up(alpha, 3, 0).is_none());
        assert_eq!(look_up(beta, 3, 0).unwrap().source, "beta.ts");
        unregister(beta);
    }

    #[test]
    fn replacement_without_a_map_clears_the_old_mapping() {
        let name = "__mapless_replacement__";
        register(
            name,
            r#"{"version":3,"sources":["old.ts"],"names":[],"mappings":"AAAA"}"#,
        )
        .unwrap();
        assert!(look_up(name, 3, 0).is_some());
        assert!(extract_and_register(name, "module.exports = {};").is_err());
        assert!(look_up(name, 3, 0).is_none());
    }
}
