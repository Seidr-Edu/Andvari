#!/usr/bin/env python3
"""Build a frozen Sonar quality-rules bundle for Andvari.

Inputs:
- profile-backup.xml: archival Sonar quality profile backup
- rules.raw.json: richer paginated rules/search export

Outputs under bundle dir:
- manifest.json
- archive/profile-backup.xml
- archive/rules.raw.json
- model/rules.lock.json
- model/rules.summary.md
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-dir", required=True, type=Path)
    parser.add_argument("--profile-backup", required=True, type=Path)
    parser.add_argument("--rules-raw", required=True, type=Path)
    parser.add_argument("--profile-key", required=True)
    parser.add_argument("--profile-name", required=True)
    parser.add_argument("--language", required=True)
    parser.add_argument("--organization", required=True)
    parser.add_argument("--rules-updated-at", required=True)
    parser.add_argument("--exported-at-utc", required=True)
    parser.add_argument("--sonar-base-url", default="https://sonarcloud.io")
    parser.add_argument("--is-built-in", action="store_true", default=False)
    parser.add_argument("--is-default", action="store_true", default=False)
    return parser.parse_args()


def read_xml_profile(path: Path) -> dict[str, dict[str, Any]]:
    root = ET.parse(path).getroot()
    rules: dict[str, dict[str, Any]] = {}
    for rule in root.findall("./rules/rule"):
        repo = (rule.findtext("repositoryKey") or "").strip()
        key = (rule.findtext("key") or "").strip()
        if not repo or not key:
            continue
        params: list[dict[str, str]] = []
        for param in rule.findall("./parameters/parameter"):
            param_key = (param.findtext("key") or "").strip()
            param_value = param.findtext("value")
            if param_key:
                params.append({"key": param_key, "value": param_value or ""})
        rule_key = f"{repo}:{key}"
        rules[rule_key] = {
            "repo": repo,
            "severity": (rule.findtext("priority") or "").strip() or None,
            "params": sorted(params, key=lambda item: item["key"]),
        }
    return rules


def load_raw_rules(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_activation_params(
    raw_params: list[dict[str, Any]],
    active_params: list[dict[str, Any]],
    xml_params: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], dict[str, str]]:
    param_defs = {param.get("key"): param for param in raw_params if param.get("key")}
    active_values = {
        param.get("key"): param.get("value", "")
        for param in active_params
        if param.get("key")
    }
    xml_values = {
        param.get("key"): param.get("value", "")
        for param in xml_params
        if param.get("key")
    }

    combined: list[dict[str, Any]] = []
    for key in sorted(set(param_defs) | set(active_values) | set(xml_values)):
        raw_param = param_defs.get(key, {})
        combined.append(
            {
                "key": key,
                "value": active_values.get(key, xml_values.get(key)),
                "default_value": raw_param.get("defaultValue"),
                "type": raw_param.get("type"),
            }
        )
    return combined, active_values or xml_values


def build_lock_rules(
    raw_payload: dict[str, Any],
    xml_rules: dict[str, dict[str, Any]],
    *,
    profile_key: str,
    language: str,
) -> tuple[list[dict[str, Any]], list[str]]:
    raw_rules = {rule["key"]: rule for rule in raw_payload.get("rules", []) if "key" in rule}
    raw_actives = raw_payload.get("actives", {})

    all_keys = sorted(set(raw_rules) | set(xml_rules))
    xml_only_keys: list[str] = []
    merged_rules: list[dict[str, Any]] = []

    for key in all_keys:
        raw_rule = raw_rules.get(key, {})
        xml_rule = xml_rules.get(key, {})
        activation_list = raw_actives.get(key) or []
        activation = activation_list[0] if activation_list else {}

        params, activation_param_values = normalize_activation_params(
            raw_rule.get("params", []),
            activation.get("params", []),
            xml_rule.get("params", []),
        )

        severity = (
            activation.get("severity")
            or raw_rule.get("severity")
            or xml_rule.get("severity")
        )
        merged = {
            "key": key,
            "name": raw_rule.get("name"),
            "lang": raw_rule.get("lang") or language,
            "repo": raw_rule.get("repo") or xml_rule.get("repo"),
            "type": raw_rule.get("type"),
            "status": raw_rule.get("status"),
            "scope": raw_rule.get("scope"),
            "impacts": raw_rule.get("impacts", []),
            "severity": severity,
            "tags": sorted(raw_rule.get("tags", [])),
            "sys_tags": sorted(raw_rule.get("sysTags", [])),
            "params": params,
            "created_at": raw_rule.get("createdAt"),
            "updated_at": raw_rule.get("updatedAt"),
            "activation": {
                "qprofile": activation.get("qProfile", profile_key),
                "inherit": activation.get("inherit"),
                "severity": severity,
                "params": [
                    {"key": key, "value": value}
                    for key, value in sorted(activation_param_values.items())
                ],
                "created_at": activation.get("createdAt"),
                "updated_at": activation.get("updatedAt"),
            },
            "partial_metadata": False,
            "metadata_sources": ["rules.raw.json", "profile-backup.xml"],
        }

        if key not in raw_rules:
            xml_only_keys.append(key)
            merged["partial_metadata"] = True
            merged["metadata_sources"] = ["profile-backup.xml"]

        merged_rules.append(merged)

    return merged_rules, xml_only_keys


def severity_order(severity: str | None) -> tuple[int, str]:
    order = {
        "BLOCKER": 0,
        "CRITICAL": 1,
        "MAJOR": 2,
        "MINOR": 3,
        "INFO": 4,
    }
    normalized = severity or "UNKNOWN"
    return (order.get(normalized, 5), normalized)


def render_summary(
    manifest: dict[str, Any],
    lock_rules: list[dict[str, Any]],
    xml_only_keys: list[str],
) -> str:
    quality_counts: Counter[str] = Counter()
    type_counts: Counter[str] = Counter()
    severity_counts: Counter[str] = Counter()
    parameterized: list[dict[str, Any]] = []
    high_severity: list[dict[str, Any]] = []

    for rule in lock_rules:
        for impact in rule.get("impacts", []):
            quality = impact.get("softwareQuality")
            if quality:
                quality_counts[quality] += 1
        rule_type = rule.get("type") or "UNKNOWN"
        type_counts[rule_type] += 1
        severity = rule.get("severity") or "UNKNOWN"
        severity_counts[severity] += 1
        if rule.get("params"):
            parameterized.append(rule)
        if severity in {"BLOCKER", "CRITICAL"}:
            high_severity.append(rule)

    high_severity.sort(key=lambda item: (severity_order(item.get("severity"))[0], item["key"]))
    parameterized.sort(key=lambda item: item["key"])

    lines = [
        "# Sonar way (Java) code-quality snapshot",
        "",
        f"- Profile: `{manifest['profile_name']}`",
        f"- Profile key: `{manifest['profile_key']}`",
        f"- Language: `{manifest['language']}`",
        f"- Rules updated at: `{manifest['rules_updated_at']}`",
        f"- Exported at (UTC): `{manifest['exported_at_utc']}`",
        f"- Active rules: `{manifest['active_rule_count']}`",
        "",
        "## How To Use This Snapshot",
        "- Read this file first.",
        "- Use the diagram as the behavioral source of truth.",
        "- Use `completion/context/sonar_rules.lock.json` only when you need exact rule metadata or parameter values.",
        "- If a quality rule appears to conflict with the diagram, preserve the diagram's behavior and satisfy the rule through naming, structure, safety, and maintainability choices.",
        "",
        "## Concern Counts",
    ]

    for quality in ("RELIABILITY", "SECURITY", "MAINTAINABILITY"):
        lines.append(f"- {quality.title()}: `{quality_counts.get(quality, 0)}`")
    lines.append(f"- Security hotspots: `{type_counts.get('SECURITY_HOTSPOT', 0)}`")
    lines.append("")
    lines.append("## Severity Counts")
    for severity in ("BLOCKER", "CRITICAL", "MAJOR", "MINOR", "INFO", "UNKNOWN"):
        lines.append(f"- {severity}: `{severity_counts.get(severity, 0)}`")
    lines.append("")
    lines.append("## Highest-Severity Rules")
    for rule in high_severity[:12]:
        lines.append(f"- `{rule['key']}`: {rule.get('name') or '(metadata only in XML backup)'}")
    if not high_severity:
        lines.append("- None")
    lines.append("")
    lines.append("## Parameterized Rules")
    if parameterized:
        for rule in parameterized:
            rendered_params = ", ".join(
                f"{param['key']}={param['value']}"
                for param in rule.get("params", [])
                if param.get("value") is not None
            )
            if rendered_params:
                lines.append(
                    f"- `{rule['key']}`: {rule.get('name') or '(metadata only in XML backup)'} "
                    f"({rendered_params})"
                )
    else:
        lines.append("- None")

    if xml_only_keys:
        lines.extend(
            [
                "",
                "## Partial Metadata Rules",
                "- The following rules were present in the profile backup XML but missing from the bulk Web API export, so their lock-file records are partial:",
                *[f"- `{key}`" for key in xml_only_keys],
            ]
        )

    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()

    bundle_dir = args.bundle_dir
    archive_dir = bundle_dir / "archive"
    model_dir = bundle_dir / "model"
    archive_dir.mkdir(parents=True, exist_ok=True)
    model_dir.mkdir(parents=True, exist_ok=True)

    xml_rules = read_xml_profile(args.profile_backup)
    raw_payload = load_raw_rules(args.rules_raw)
    lock_rules, xml_only_keys = build_lock_rules(
        raw_payload,
        xml_rules,
        profile_key=args.profile_key,
        language=args.language,
    )

    archive_profile = archive_dir / "profile-backup.xml"
    archive_raw = archive_dir / "rules.raw.json"
    shutil.copy2(args.profile_backup, archive_profile)
    shutil.copy2(args.rules_raw, archive_raw)

    manifest = {
        "schema_version": 1,
        "profile_name": args.profile_name,
        "profile_key": args.profile_key,
        "language": args.language,
        "organization": args.organization,
        "sonar_base_url": args.sonar_base_url,
        "is_built_in": args.is_built_in,
        "is_default": args.is_default,
        "rules_updated_at": args.rules_updated_at,
        "exported_at_utc": args.exported_at_utc,
        "active_rule_count": len(lock_rules),
        "api_rule_count": len(raw_payload.get("rules", [])),
        "xml_only_rule_count": len(xml_only_keys),
        "xml_only_rule_keys": xml_only_keys,
    }

    lock_payload = {
        "schema_version": 1,
        "exported_at_utc": args.exported_at_utc,
        "profile": {
            "key": args.profile_key,
            "name": args.profile_name,
            "language": args.language,
            "organization": args.organization,
            "rules_updated_at": args.rules_updated_at,
        },
        "rules": lock_rules,
    }
    lock_path = model_dir / "rules.lock.json"
    lock_path.write_text(json.dumps(lock_payload, indent=2) + "\n", encoding="utf-8")

    summary_path = model_dir / "rules.summary.md"
    summary_path.write_text(
        render_summary(manifest, lock_rules, xml_only_keys),
        encoding="utf-8",
    )

    manifest["artifacts"] = {
        "archive/profile-backup.xml": {"sha256": sha256_file(archive_profile)},
        "archive/rules.raw.json": {"sha256": sha256_file(archive_raw)},
        "model/rules.lock.json": {"sha256": sha256_file(lock_path)},
        "model/rules.summary.md": {"sha256": sha256_file(summary_path)},
    }
    manifest_path = bundle_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
