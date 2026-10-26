#!/usr/bin/env python3
"""Read-only capability evidence checks and local SQLite export.

This validates records, not the truth of captured evidence. It never requests
the site, submits account operations, or treats mock success as acceptance.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import tempfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGISTRY = ROOT / "docs/hanime_api/registry.json"
KINDS = {
    "official_dom", "official_script", "official_network", "user_screenshot",
    "user_diagnostic", "local_implementation", "third_party_code",
}
OFFICIAL = {"official_dom", "official_script", "official_network"}
STATUSES = {"unknown", "observed", "passed", "failed", "not_applicable"}
CHECKPOINTS = ("existence", "target", "read", "write", "readback", "return_device")
CLAIMS = {"candidate", "observed_static", "observed_runtime"}
ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")
HASH = re.compile(r"^[0-9a-fA-F]{64}$")
EVIDENCE_LIMIT = (
    "Record validation does not authenticate evidence. Screenshots alone do "
    "not verify a server write or readback; mocks and local code do not verify "
    "real site functionality."
)


def _text(value):
    return isinstance(value, str) and bool(value.strip())


def _origin(url):
    try:
        parsed = urlsplit(url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
            return None
        port = parsed.port
        return (parsed.scheme, parsed.hostname.lower(), port or 443)
    except (AttributeError, TypeError, ValueError):
        return None


def validate_registry(data):
    """Return all structural and evidence-policy errors without side effects."""
    errors = []

    def error(at, message):
        errors.append(f"{at}: {message}")

    def required(obj, keys, at):
        if not isinstance(obj, dict):
            error(at, "must be an object")
            return False
        for key in keys:
            if key not in obj:
                error(at, f"missing {key}")
        return True

    def strings(value, at, allow_empty=True):
        if not isinstance(value, list):
            error(at, "must be an array of strings")
            return []
        for i, entry in enumerate(value):
            if not isinstance(entry, str) or (not allow_empty and not entry.strip()):
                error(f"{at}[{i}]", "must be a nonempty string" if not allow_empty else "must be a string")
        return value

    if not required(data, ("schemaVersion", "siteOrigin", "updatedOn", "evidence", "entities", "capabilities", "contracts", "conflicts"), "registry"):
        return errors
    if type(data.get("schemaVersion")) is not int or data.get("schemaVersion") != 1:
        error("schemaVersion", "must be integer 1")
    site_origin = _origin(data.get("siteOrigin"))
    if not site_origin:
        error("siteOrigin", "must be an HTTPS origin without credentials")
    else:
        parsed = urlsplit(data["siteOrigin"])
        if parsed.path not in ("", "/") or parsed.query or parsed.fragment:
            error("siteOrigin", "must contain no path, query or fragment")
    try:
        date = data.get("updatedOn")
        if not isinstance(date, str) or dt.date.fromisoformat(date).isoformat() != date:
            raise ValueError()
    except ValueError:
        error("updatedOn", "must be YYYY-MM-DD")

    groups = {}
    for name in ("evidence", "entities", "capabilities", "contracts", "conflicts"):
        entries = data.get(name)
        if not isinstance(entries, list):
            error(name, "must be an array")
            entries = []
        indexed = {}
        for i, entry in enumerate(entries):
            at = f"{name}[{i}]"
            if not required(entry, ("id",), at):
                continue
            ident = entry.get("id")
            if not isinstance(ident, str) or not ID.fullmatch(ident):
                error(at, "id must use letters, digits, dot, dash, underscore or colon")
                continue
            if ident in indexed:
                error(at, f"duplicate id {ident}")
            else:
                indexed[ident] = entry
        groups[name] = indexed

    def refs(value, group, at):
        entries = strings(value, at, False)
        valid = []
        for ident in entries:
            if not isinstance(ident, str):
                continue
            if ident not in groups[group]:
                error(at, f"unknown {group} reference {ident}")
            else:
                valid.append(groups[group][ident])
        if len([x for x in entries if isinstance(x, str)]) != len({x for x in entries if isinstance(x, str)}):
            error(at, "duplicate references")
        return valid

    for ident, ev in groups["evidence"].items():
        at = f"evidence.{ident}"
        required(ev, ("kind", "observedOn", "source", "context", "facts", "limitations"), at)
        if not isinstance(ev.get("kind"), str) or ev.get("kind") not in KINDS:
            error(at + ".kind", "unsupported evidence kind")
        try:
            date = ev.get("observedOn")
            if not isinstance(date, str) or dt.date.fromisoformat(date).isoformat() != date:
                raise ValueError()
        except ValueError:
            error(at + ".observedOn", "must be YYYY-MM-DD")
        source = ev.get("source")
        if required(source, (), at + ".source"):
            if not (_text(source.get("path")) or _text(source.get("url"))):
                error(at + ".source", "must include path or url")
            if "sha256" in source and (not isinstance(source["sha256"], str) or not HASH.fullmatch(source["sha256"])):
                error(at + ".source.sha256", "must be a SHA-256 hex digest")
        context = ev.get("context")
        if required(context, ("auth",), at + ".context"):
            if not _text(context.get("auth")):
                error(at + ".context.auth", "must describe authentication context")
            for flag in ("synthetic", "mock", "nativeAdapterExecuted", "actualHostJavaScriptExecuted", "actualPluginJavaScriptExecuted", "dartControllerExecuted", "iosPlatformBridgeExecuted", "deviceUiExecuted"):
                if flag in context and type(context[flag]) is not bool:
                    error(at + ".context." + flag, "must be boolean")
        strings(ev.get("facts"), at + ".facts")
        strings(ev.get("limitations"), at + ".limitations")
        if "supersededBy" in ev:
            refs(ev["supersededBy"], "evidence", at + ".supersededBy")

    for ident, entity in groups["entities"].items():
        at = f"entities.{ident}"
        required(entity, ("description", "idPolicy"), at)
        if not _text(entity.get("description")):
            error(at + ".description", "must be nonempty text")
        if not (_text(entity.get("idPolicy")) or isinstance(entity.get("idPolicy"), dict)):
            error(at + ".idPolicy", "must be text or an object")

    def authentic(ev):
        context = ev.get("context", {})
        return isinstance(context, dict) and context.get("synthetic") is False and context.get("mock") is not True

    def official(ev):
        source = ev.get("source", {})
        context = ev.get("context", {})
        return (isinstance(ev.get("kind"), str) and ev.get("kind") in OFFICIAL
                and isinstance(source, dict) and isinstance(context, dict)
                and site_origin is not None and _origin(source.get("url")) == site_origin
                and context.get("synthetic") is not True
                and context.get("mock") is not True)

    for ident, cap in groups["capabilities"].items():
        at = f"capabilities.{ident}"
        required(cap, ("title", "area", "entityTypes", "evidenceRefs", "implementationRefs", "checkpoints", "missing"), at)
        for key in ("title", "area"):
            if not _text(cap.get(key)):
                error(at + "." + key, "must be nonempty text")
        refs(cap.get("entityTypes"), "entities", at + ".entityTypes")
        refs(cap.get("evidenceRefs"), "evidence", at + ".evidenceRefs")
        strings(cap.get("missing"), at + ".missing")
        if "supersededByCapabilities" in cap:
            refs(cap["supersededByCapabilities"], "capabilities", at + ".supersededByCapabilities")
        impl = cap.get("implementationRefs")
        if not isinstance(impl, list):
            error(at + ".implementationRefs", "must be an array")
        else:
            for i, entry in enumerate(impl):
                pos = f"{at}.implementationRefs[{i}]"
                if required(entry, ("file", "line"), pos):
                    if not _text(entry.get("file")) or type(entry.get("line")) is not int or entry["line"] < 1:
                        error(pos, "must contain file text and positive integer line")
        checkpoints = cap.get("checkpoints")
        if not required(checkpoints, CHECKPOINTS, at + ".checkpoints"):
            continue
        for name in CHECKPOINTS:
            point = checkpoints.get(name)
            pos = at + ".checkpoints." + name
            if not required(point, ("status", "evidenceRefs", "note"), pos):
                continue
            if not isinstance(point.get("status"), str) or point.get("status") not in STATUSES:
                error(pos + ".status", "unsupported status")
            if not isinstance(point.get("note"), str):
                error(pos + ".note", "must be a string")
            attached = refs(point.get("evidenceRefs"), "evidence", pos + ".evidenceRefs")
            if point.get("status") in ("observed", "passed", "failed") and not attached:
                error(pos, "observed/passed/failed status requires referenced evidence")
            if point.get("status") == "passed" and name in ("write", "readback"):
                if not any(official(e) and e.get("kind") == "official_network" and authentic(e)
                           and e.get("context", {}).get("nativeAdapterExecuted") is True
                           and e.get("context", {}).get("scope") != "original_site_ui_only" for e in attached):
                    error(pos, "passed requires same-origin official_network evidence with context.synthetic=false and nativeAdapterExecuted=true; original-site UI, screenshots, mocks, local and third-party code are insufficient")
            if point.get("status") == "passed" and name == "return_device":
                if not any(e.get("kind") in ("user_screenshot", "user_diagnostic") and authentic(e) for e in attached):
                    error(pos, "passed requires device screenshot/diagnostic with context.synthetic=false; screenshots alone cannot verify a server write")

    for ident, contract in groups["contracts"].items():
        at = f"contracts.{ident}"
        required(contract, ("capabilityId", "claimLevel", "sourceRefs", "method", "route", "request", "preconditions", "success", "failure", "readback", "notes"), at)
        refs([contract.get("capabilityId")], "capabilities", at + ".capabilityId")
        if not isinstance(contract.get("claimLevel"), str) or contract.get("claimLevel") not in CLAIMS:
            error(at + ".claimLevel", "unsupported claim level")
        sources = refs(contract.get("sourceRefs"), "evidence", at + ".sourceRefs")
        if "supersededBy" in contract:
            refs(contract["supersededBy"], "contracts", at + ".supersededBy")
        if not sources:
            error(at + ".sourceRefs", "a candidate also needs provenance")
        if contract.get("claimLevel") in ("observed_static", "observed_runtime"):
            observed = [e for e in sources if official(e)]
            if not observed:
                error(at, "observed contract requires same-origin first-party DOM, script or network evidence; local/third-party/screenshot evidence is insufficient")
            if contract["claimLevel"] == "observed_runtime" and not any(e.get("kind") == "official_network" and authentic(e) for e in observed):
                error(at, "observed_runtime requires official_network evidence with context.synthetic=false")
        for key in ("method", "route"):
            if not _text(contract.get(key)):
                error(at + "." + key, "must be nonempty text")
        request = contract.get("request")
        if required(request, ("fields",), at + ".request"):
            fields = request.get("fields")
            if not isinstance(fields, list):
                error(at + ".request.fields", "must be an array")
            else:
                names = []
                for field in fields:
                    name = field.get("name") if isinstance(field, dict) else field
                    if not _text(name):
                        error(at + ".request.fields", "field must be text or an object containing name")
                    else:
                        names.append(name)
                if len(names) != len(set(names)):
                    error(at + ".request.fields", "duplicate field names")
        for key in ("preconditions", "success", "failure", "readback", "notes"):
            strings(contract.get(key), at + "." + key)

    for ident, conflict in groups["conflicts"].items():
        at = f"conflicts.{ident}"
        required(conflict, ("contractIds", "evidenceRefs", "description", "resolution"), at)
        refs(conflict.get("contractIds"), "contracts", at + ".contractIds")
        refs(conflict.get("evidenceRefs"), "evidence", at + ".evidenceRefs")
        if not _text(conflict.get("description")):
            error(at + ".description", "must be nonempty text")
        if conflict.get("resolution") is not None and not _text(conflict.get("resolution")):
            error(at + ".resolution", "must be null or nonempty text")
    observations = data.get("runtimeProtocolObservations", [])
    if not isinstance(observations, list):
        error("runtimeProtocolObservations", "must be an array")
    else:
        for i, observation in enumerate(observations):
            at = f"runtimeProtocolObservations[{i}]"
            if not required(observation, ("evidenceRef", "scope"), at):
                continue
            attached = refs([observation.get("evidenceRef")], "evidence", at + ".evidenceRef")
            if not _text(observation.get("scope")):
                error(at + ".scope", "must be nonempty text")
            for ev in attached:
                if not (official(ev) and ev.get("kind") == "official_network" and authentic(ev)):
                    error(at, "runtime observation requires authentic same-origin official_network evidence")
                context = ev.get("context", {})
                if observation.get("scope") != context.get("scope"):
                    error(at + ".scope", "must match referenced evidence context")
                for flag in ("actualHostJavaScriptExecuted", "actualPluginJavaScriptExecuted", "nativeAdapterExecuted"):
                    if flag in observation and (type(observation[flag]) is not bool or observation[flag] != context.get(flag)):
                        error(at + "." + flag, "must be boolean and match referenced evidence context")
    corrections = data.get("implementationCorrectionChecklist", [])
    if not isinstance(corrections, list):
        error("implementationCorrectionChecklist", "must be an array")
    else:
        for i, correction in enumerate(corrections):
            if isinstance(correction, dict) and "evidenceRefs" in correction:
                refs(correction["evidenceRefs"], "evidence", f"implementationCorrectionChecklist[{i}].evidenceRefs")
    archives = data.get("implementationSourceArchives", [])
    if not isinstance(archives, list):
        error("implementationSourceArchives", "must be an array")
    else:
        for i, archive in enumerate(archives):
            at = f"implementationSourceArchives[{i}]"
            if not required(archive, ("evidenceRef", "sourceSha256", "sourceArchive", "bodySha256", "bodyArchive"), at):
                continue
            attached = refs([archive.get("evidenceRef")], "evidence", at + ".evidenceRef")
            for key in ("sourceSha256", "bodySha256"):
                if not isinstance(archive.get(key), str) or not HASH.fullmatch(archive[key]):
                    error(at + "." + key, "must be a SHA-256 hex digest")
            for key in ("sourceArchive", "bodyArchive"):
                if not _text(archive.get(key)):
                    error(at + "." + key, "must be nonempty text")
            for ev in attached:
                source = ev.get("source")
                if archive.get("sourceSha256") != (source.get("sha256") if isinstance(source, dict) else None):
                    error(at + ".sourceSha256", "must match historical evidence source hash")
    return errors


def export_sqlite(data, output, *, force=False):
    errors = validate_registry(data)
    if errors:
        raise ValueError("Registry validation failed:\n" + "\n".join(errors))
    output = Path(output).resolve()
    if output.exists() and not force:
        raise FileExistsError(f"Refusing to overwrite {output}; use --force")
    output.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=output.name + ".", suffix=".tmp", dir=output.parent)
    os.close(descriptor)
    encode = lambda value: json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    try:
        with sqlite3.connect(temporary) as conn:
            conn.executescript("""
                CREATE TABLE metadata(key TEXT PRIMARY KEY, value_json TEXT NOT NULL);
                CREATE TABLE evidence(id TEXT PRIMARY KEY, kind TEXT NOT NULL, observed_on TEXT NOT NULL,
                  source_json TEXT NOT NULL, context_json TEXT NOT NULL, facts_json TEXT NOT NULL, limitations_json TEXT NOT NULL, record_json TEXT NOT NULL);
                CREATE TABLE entities(id TEXT PRIMARY KEY, description TEXT NOT NULL, id_policy_json TEXT NOT NULL, record_json TEXT NOT NULL);
                CREATE TABLE capabilities(id TEXT PRIMARY KEY, title TEXT NOT NULL, area TEXT NOT NULL,
                  entity_types_json TEXT NOT NULL, evidence_refs_json TEXT NOT NULL, implementation_refs_json TEXT NOT NULL,
                  checkpoints_json TEXT NOT NULL, missing_json TEXT NOT NULL, record_json TEXT NOT NULL);
                CREATE TABLE contracts(id TEXT PRIMARY KEY, capability_id TEXT NOT NULL REFERENCES capabilities(id),
                  claim_level TEXT NOT NULL, source_refs_json TEXT NOT NULL, method TEXT NOT NULL, route TEXT NOT NULL,
                  request_json TEXT NOT NULL, preconditions_json TEXT NOT NULL, success_json TEXT NOT NULL,
                  failure_json TEXT NOT NULL, readback_json TEXT NOT NULL, notes_json TEXT NOT NULL, record_json TEXT NOT NULL);
                CREATE TABLE conflicts(id TEXT PRIMARY KEY, contract_ids_json TEXT NOT NULL, evidence_refs_json TEXT NOT NULL,
                  description TEXT NOT NULL, resolution TEXT, record_json TEXT NOT NULL);
                CREATE INDEX contracts_capability ON contracts(capability_id);
                CREATE INDEX capabilities_area ON capabilities(area);
                CREATE VIEW capability_status AS SELECT id,title,area,
                  json_extract(checkpoints_json,'$.existence.status') AS existence,
                  json_extract(checkpoints_json,'$.target.status') AS target,
                  json_extract(checkpoints_json,'$.read.status') AS read,
                  json_extract(checkpoints_json,'$.write.status') AS write,
                  json_extract(checkpoints_json,'$.readback.status') AS readback,
                  json_extract(checkpoints_json,'$.return_device.status') AS return_device,
                  json_extract(record_json,'$.scope.requiredForGoal') AS required_for_goal FROM capabilities;
                CREATE VIEW unverified_contracts AS SELECT * FROM contracts WHERE claim_level != 'observed_runtime';
            """)
            for key, value in data.items():
                if key not in ("capabilities", "contracts", "evidence", "entities", "conflicts"):
                    conn.execute("INSERT INTO metadata VALUES (?,?)", (key, encode(value)))
            conn.execute("INSERT INTO metadata VALUES (?,?)", ("evidenceLimit", encode(EVIDENCE_LIMIT)))
            for x in data["evidence"]:
                conn.execute("INSERT INTO evidence VALUES (?,?,?,?,?,?,?,?)", (x["id"], x["kind"], x["observedOn"], *[encode(x[k]) for k in ("source", "context", "facts", "limitations")], encode(x)))
            for x in data["entities"]:
                conn.execute("INSERT INTO entities VALUES (?,?,?,?)", (x["id"], x["description"], encode(x["idPolicy"]), encode(x)))
            for x in data["capabilities"]:
                conn.execute("INSERT INTO capabilities VALUES (?,?,?,?,?,?,?,?,?)", (x["id"], x["title"], x["area"], *[encode(x[k]) for k in ("entityTypes", "evidenceRefs", "implementationRefs", "checkpoints", "missing")], encode(x)))
            for x in data["contracts"]:
                conn.execute("INSERT INTO contracts VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", (x["id"], x["capabilityId"], x["claimLevel"], encode(x["sourceRefs"]), x["method"], x["route"], *[encode(x[k]) for k in ("request", "preconditions", "success", "failure", "readback", "notes")], encode(x)))
            for x in data["conflicts"]:
                conn.execute("INSERT INTO conflicts VALUES (?,?,?,?,?,?)", (x["id"], encode(x["contractIds"]), encode(x["evidenceRefs"]), x["description"], x["resolution"], encode(x)))
        if force:
            os.replace(temporary, output)
        else:
            os.link(temporary, output)
            os.unlink(temporary)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return output


def render_markdown(data):
    """Render the full task index from authoritative JSON, without new claims."""
    errors = validate_registry(data)
    if errors:
        raise ValueError("Registry validation failed:\n" + "\n".join(errors))

    def cell(value):
        return str(value).replace("|", "\\|").replace("\r", " ").replace("\n", " ")

    out = ["# Hanime 能力与协议逐项索引", "", "本文件由 `api_registry.py render` 从 `registry.json` 生成；请修改主JSON后重新生成，勿手写另一套事实。", "", f"登记日期：{data['updatedOn']}。{len(data['capabilities'])}项能力、{len(data['contracts'])}份协议记录、{len(data['evidence'])}条证据。", "", "`observed_static` 只表示原站DOM/脚本结构已观察，不等于提交、服务器回读或设备验收通过。评论/回复发布按用户要求可选；读取仍为必需。历史候选和已被新证据替代的合同仍保留来源。", ""]
    closure = data.get("inventoryClosure", {})
    if closure:
        out += ["静态盘点阶段：" + cell(closure.get("status", "见主数据")) + "。" + cell(closure.get("note", "")), ""]
    if data.get("runtimeProtocolObservations"):
        scopes = sorted({entry["scope"] for entry in data["runtimeProtocolObservations"]})
        out += ["已登记的运行范围：" + "、".join("`" + cell(scope) + "`" for scope in scopes) + "。原站UI、实际宿主JS、宿主与插件JS、独立GET/DOM结构检查，以及纯Dart URL模型加GET分别按来源记录；它们不能互相代验，也不替代完整Dart/controller、App平台bridge、原生adapter及设备验收。逐项查看检查点说明与合同范围。", ""]
    if data.get("implementationSourceArchives"):
        out += ["源码历史版本与归档：旧来源的路径、摘要及合同归属保持不变；同路径当前文件可能已更新，核验历史内容请使用下面的精确归档。", "", "| 历史证据ID | 完整源SHA256 | 完整源归档 | 导出body SHA256 | body归档 |", "| --- | --- | --- | --- | --- |"]
        for archive in data["implementationSourceArchives"]:
            out.append("| " + " | ".join(cell(archive[key]) for key in ("evidenceRef", "sourceSha256", "sourceArchive", "bodySha256", "bodyArchive")) + " |")
        out.append("")
    if data.get("temporarySiteObjectLifecycle"):
        out += ["站点测试对象按观察时点登记；浏览器probe清理不等于站点对象删除。", "", "| 证据ID | 当时对象状态 | 已永久删除 | 整体账号已还原 |", "| --- | --- | --- | --- |"]
        for entry in data["temporarySiteObjectLifecycle"]:
            out.append("| " + " | ".join(cell(entry.get(key, "unknown")) for key in ("evidenceRef", "stateAtObservation", "permanentDeletionPerformed", "originalAccountFullyRestored")) + " |")
        out.append("")
    out += ["| 能力ID | 标题 | 区域 | 存在 | 目标 | 读取 | 提交 | 回读 | 返回 | 目标要求 |", "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for cap in data["capabilities"]:
        s = cap["checkpoints"]
        scope = cap.get("scope", {})
        requirement = "可选" if scope.get("requiredForGoal") is False else "必需" if scope.get("requiredForGoal") is True else "盘点/边界记录"
        values = [cap["id"], cap["title"], cap["area"], *[s[k]["status"] for k in CHECKPOINTS], requirement]
        out.append("| " + " | ".join(cell(v) for v in values) + " |")
    out.append("")
    evidence = {e["id"]: e for e in data["evidence"]}
    for cap in data["capabilities"]:
        out += [f"## {cap['id']} · {cap['title']}", "", "实体：" + ", ".join(cap["entityTypes"]) + "。", ""]
        if cap.get("scope"):
            out += ["范围：" + cell(cap["scope"].get("note", "")), ""]
        if cap.get("implementationStatus"):
            out += ["源码实施状态：`" + cell(cap["implementationStatus"]) + "`。此状态不提升下面的真实功能或设备检查点。", ""]
        if cap.get("implementationRefs"):
            out += ["实现定位：" + "; ".join(cell(ref["file"]) + ":" + str(ref["line"]) for ref in cap["implementationRefs"]) + "。精确版本见对应local_implementation证据中的摘要。", ""]
        out += ["| 检查点 | 状态 | 证据ID | 说明 |", "| --- | --- | --- | --- |"]
        for name in CHECKPOINTS:
            point = cap["checkpoints"][name]
            out.append("| " + " | ".join(cell(v) for v in (name, point["status"], ", ".join(point["evidenceRefs"]) or "—", point["note"])) + " |")
        contracts = [c for c in data["contracts"] if c["capabilityId"] == cap["id"]]
        out += ["", "协议记录（候选、当前观察及历史分别保留）：", "", "| 合同ID | 等级/状态 | 范围 | 方法 | 路由 | 字段名 | 来源ID |", "| --- | --- | --- | --- | --- | --- | --- |"]
        for contract in contracts:
            fields = [f["name"] if isinstance(f, dict) else f for f in contract["request"]["fields"]]
            level = contract["claimLevel"] + (" / historical, superseded" if contract.get("supersededBy") else "")
            out.append("| " + " | ".join(cell(v) for v in (contract["id"], level, contract.get("scope", "按来源及检查点范围"), contract["method"], contract["route"], ", ".join(fields) or "—", ", ".join(contract["sourceRefs"]))) + " |")
        if not contracts:
            out.append("| — | 尚无协议依据 | — | — | — | — | — |")
        if cap.get("dataFields"):
            out += ["", "数据字段语义：", "", "| 字段 | 原站来源 | 解析/显示规则 | 边界 |", "| --- | --- | --- | --- |"]
            for field in cap["dataFields"]:
                parse = field.get("numericParsing")
                out.append("| " + " | ".join(cell(v) for v in (field["id"], field.get("displaySelector", field.get("source", "")), json.dumps(parse, ensure_ascii=False) if parse is not None else "保留原始显示；不是数值", field.get("boundary", ""))) + " |")
        out += ["", "仍需处理/验收：", ""]
        out += ["- " + cell(m) for m in cap["missing"]] or ["- 见各检查点；没有自动完成推断。"]
        out += ["", "证据定位：", ""]
        for eid in cap["evidenceRefs"]:
            ev = evidence[eid]
            source = ev["source"]
            out.append("- " + cell(eid) + " · " + ev["kind"] + " · " + ev["observedOn"] + " · " + cell(source.get("url", source.get("path", ""))) + (" · commit=" + cell(source["commit"]) if source.get("commit") else ""))
        out.append("")
    if data.get("implementationCorrectionChecklist"):
        out += ["## 已证实的实现修正清单", "", "保留原问题与当前分层修正状态；已观察JS运行不代表完整原生或设备验收通过。", "", "| 修正ID | 阶段 | 当前状态 | 原问题及当前说明 | 证据ID |", "| --- | --- | --- | --- | --- |"]
        for fix in data["implementationCorrectionChecklist"]:
            out.append("| " + " | ".join(cell(v) for v in (fix["id"], fix["phase"], fix.get("status", "unknown"), fix["description"] + " " + fix.get("currentNote", ""), ", ".join(fix["evidenceRefs"]))) + " |")
        out.append("")
    out += ["## 冲突与部分解决事项", ""]
    for conflict in data["conflicts"]:
        out += ["- **" + conflict["id"] + "**：" + cell(conflict["description"]), "  - 处理：" + cell(conflict["resolution"] or "待核对/修正"), "  - 合同：" + cell(", ".join(conflict["contractIds"])), "  - 证据：" + cell(", ".join(conflict["evidenceRefs"]))]
    return "\n".join(out) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, epilog=EVIDENCE_LIMIT)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "list", "show", "export", "render"):
        command = commands.add_parser(name)
        command.add_argument("--registry", type=Path, default=argparse.SUPPRESS)
        if name == "list":
            command.add_argument("--area")
        elif name == "show":
            command.add_argument("id")
        elif name == "export":
            command.add_argument("--sqlite", type=Path, required=True)
            command.add_argument("--force", action="store_true", help="Replace an existing local export")
        elif name == "render":
            command.add_argument("--output", type=Path, help="Write a generated Markdown index; otherwise stdout")
    args = parser.parse_args(argv)
    try:
        data = json.loads(args.registry.read_text())
        errors = validate_registry(data)
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        if args.command == "validate":
            print(f"Registry valid: {len(data['capabilities'])} capabilities; {len(data['contracts'])} contracts.")
            print(EVIDENCE_LIMIT)
        elif args.command == "list":
            for cap in data["capabilities"]:
                if args.area is None or cap["area"] == args.area:
                    state = cap["checkpoints"]
                    contracts = [c for c in data["contracts"] if c["capabilityId"] == cap["id"] and not c.get("supersededBy")]
                    counts = {level: sum(c["claimLevel"] == level for c in contracts) for level in sorted(CLAIMS)}
                    print(f"{cap['id']}\t{cap['area']}\t{cap['title']}\tcandidate={counts['candidate']}\tstatic={counts['observed_static']}\truntime={counts['observed_runtime']}\twrite={state['write']['status']}\treadback={state['readback']['status']}")
        elif args.command == "show":
            matches = [(name, item) for name in ("capabilities", "contracts", "evidence", "entities", "conflicts") for item in data[name] if item["id"] == args.id]
            if not matches:
                print(f"Unknown id: {args.id}", file=sys.stderr)
                return 1
            result = {}
            evidence_ids = set()
            for group, item in matches:
                result[group] = item
                if group == "evidence":
                    evidence_ids.add(item["id"])
                if group == "capabilities":
                    related = [c for c in data["contracts"] if c["capabilityId"] == args.id]
                    result["relatedContracts"] = related
                    evidence_ids = set(item["evidenceRefs"])
                    for contract in related:
                        evidence_ids.update(contract["sourceRefs"])
                    for point in item["checkpoints"].values():
                        evidence_ids.update(point["evidenceRefs"])
                    result["relatedEvidence"] = [e for e in data["evidence"] if e["id"] in evidence_ids]
                    result["relatedConflicts"] = [c for c in data["conflicts"] if any(e in evidence_ids for e in c["evidenceRefs"])]
            archives = [entry for entry in data.get("implementationSourceArchives", []) if entry["evidenceRef"] in evidence_ids]
            if archives:
                result["relatedSourceArchives"] = archives
            print(json.dumps(result, ensure_ascii=False, indent=2))
        elif args.command == "render":
            markdown = render_markdown(data)
            if args.output:
                if args.output.resolve() == args.registry.resolve():
                    raise ValueError("Markdown index cannot overwrite registry source")
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(markdown)
                print(args.output)
            else:
                print(markdown, end="")
        else:
            if args.sqlite.resolve() == args.registry.resolve():
                raise ValueError("SQLite export cannot overwrite registry source")
            print(export_sqlite(data, args.sqlite, force=args.force))
        return 0
    except (OSError, ValueError, sqlite3.Error) as error:
        print(f"Registry error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
