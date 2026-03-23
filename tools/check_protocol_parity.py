#!/usr/bin/env python3
"""
Protocol parity checker for AmpersandBoxDesign.

Checks consistency across:
- SPEC.md
- README.md
- schema files
- contracts
- registry artifact
- site snippets

Usage:
  python3 tools/check_protocol_parity.py
  python3 tools/check_protocol_parity.py --root /path/to/AmpersandBoxDesign
  python3 tools/check_protocol_parity.py --json
  python3 tools/check_protocol_parity.py --strict
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple


CAPABILITIES = {"&reason.deliberate", "&reason.attend"}
MODEL_TIERS = {"local_small", "local_large", "cloud_frontier"}
TYPE_TOKENS = {
    "topology_result",
    "deliberation_result",
    "attention_map",
    "attention_cycle",
    "coverage_assessment",
}

REQUIRED_FILES = [
    "SPEC.md",
    "README.md",
    "site/protocol.html",
    "protocol/schema/index.html",
    "protocol/registry/index.html",
    "protocol/schema/v0.1.0/ampersand.schema.json",
    "protocol/schema/v0.1.0/capability-contract.schema.json",
    "protocol/schema/v0.1.0/registry.schema.json",
    "protocol/registry/v0.1.0/capabilities.registry.json",
    "contracts/v0.1.0/reason.deliberate.contract.json",
    "contracts/v0.1.0/reason.attend.contract.json",
    "docs/registry/reason.deliberate.md",
    "docs/registry/reason.attend.md",
]


@dataclass
class Finding:
    kind: str  # "error" | "warning"
    check: str
    message: str


@dataclass
class Report:
    findings: List[Finding] = field(default_factory=list)

    def error(self, check: str, message: str) -> None:
        self.findings.append(Finding("error", check, message))

    def warn(self, check: str, message: str) -> None:
        self.findings.append(Finding("warning", check, message))

    @property
    def errors(self) -> List[Finding]:
        return [f for f in self.findings if f.kind == "error"]

    @property
    def warnings(self) -> List[Finding]:
        return [f for f in self.findings if f.kind == "warning"]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def read_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def token_present(text: str, token: str) -> bool:
    if token in text:
        return True
    # Handle common HTML-escaped form for capability IDs in generated site content.
    escaped = token.replace("&", "&amp;")
    return escaped in text


def has_all_tokens(text: str, tokens: Iterable[str]) -> Set[str]:
    missing = set()
    for token in tokens:
        if not token_present(text, token):
            missing.add(token)
    return missing


def nested_get(obj: Dict[str, Any], *keys: str, default: Any = None) -> Any:
    cur: Any = obj
    for k in keys:
        if not isinstance(cur, dict) or k not in cur:
            return default
        cur = cur[k]
    return cur


def normalize_refs(refs: Iterable[str]) -> Set[str]:
    return {str(r).strip() for r in refs if isinstance(r, str)}


def check_required_files(root: Path, report: Report) -> None:
    check = "required-files"
    for rel in REQUIRED_FILES:
        p = root / rel
        if not p.exists():
            report.error(check, f"Missing required file: {rel}")


def check_contracts(root: Path, report: Report) -> Dict[str, Dict[str, Any]]:
    check = "contracts"
    result: Dict[str, Dict[str, Any]] = {}
    for rel, cap, expected_ops in [
        (
            "contracts/v0.1.0/reason.deliberate.contract.json",
            "&reason.deliberate",
            {"deliberate", "decompose", "reconcile"},
        ),
        (
            "contracts/v0.1.0/reason.attend.contract.json",
            "&reason.attend",
            {"survey", "triage", "dispatch"},
        ),
    ]:
        p = root / rel
        if not p.exists():
            continue

        data = read_json(p)
        result[cap] = data

        capability = data.get("capability")
        if capability != cap:
            report.error(
                check,
                f"{rel}: capability mismatch (expected {cap}, got {capability!r})",
            )

        operations = data.get("operations", {})
        if not isinstance(operations, dict):
            report.error(check, f"{rel}: operations must be an object")
            continue

        op_names = set(operations.keys())
        missing = expected_ops - op_names
        extra = op_names - expected_ops
        if missing:
            report.error(check, f"{rel}: missing operations {sorted(missing)}")
        if extra:
            report.warn(check, f"{rel}: unexpected extra operations {sorted(extra)}")

        # Minimal IO token checks
        if cap == "&reason.deliberate":
            deliberate = operations.get("deliberate", {})
            if deliberate.get("in") != "topology_result":
                report.error(
                    check,
                    f"{rel}: deliberate.in should be 'topology_result'",
                )
            if deliberate.get("out") != "deliberation_result":
                report.error(
                    check,
                    f"{rel}: deliberate.out should be 'deliberation_result'",
                )
        if cap == "&reason.attend":
            dispatch = operations.get("dispatch", {})
            if dispatch.get("out") != "attention_cycle":
                report.error(
                    check,
                    f"{rel}: dispatch.out should be 'attention_cycle'",
                )

        metadata = data.get("metadata", {})
        if isinstance(metadata, dict):
            tiers = (
                metadata.get("model_tiers")
                or metadata.get("supports_model_tiers")
                or []
            )
            if isinstance(tiers, list):
                tier_set = set(str(x) for x in tiers)
                missing_tiers = MODEL_TIERS - tier_set
                if missing_tiers:
                    report.warn(
                        check,
                        f"{rel}: metadata missing model tiers {sorted(missing_tiers)}",
                    )
        else:
            report.warn(check, f"{rel}: metadata missing or not object")

    return result


def check_registry(root: Path, report: Report) -> Dict[str, Any]:
    check = "registry"
    p = root / "protocol/registry/v0.1.0/capabilities.registry.json"
    if not p.exists():
        return {}

    data = read_json(p)

    reason = data.get("&reason", {})
    if not isinstance(reason, dict):
        report.error(check, "Registry missing '&reason' object")
        return data

    subtypes = nested_get(reason, "subtypes", default={})
    if not isinstance(subtypes, dict):
        report.error(check, "Registry '&reason.subtypes' must be object")
        return data

    for subtype, contract_ref in [
        ("deliberate", "/contracts/v0.1.0/reason.deliberate.contract.json"),
        ("attend", "/contracts/v0.1.0/reason.attend.contract.json"),
    ]:
        s = subtypes.get(subtype)
        if not isinstance(s, dict):
            report.error(check, f"Registry missing '&reason.{subtype}' subtype")
            continue

        actual_ref = s.get("contract_ref")
        if actual_ref != contract_ref:
            report.error(
                check,
                f"Registry '&reason.{subtype}' contract_ref mismatch "
                f"(expected {contract_ref}, got {actual_ref!r})",
            )

        # Verify referenced file exists
        ref_path = root / contract_ref.lstrip("/")
        if not ref_path.exists():
            report.error(
                check,
                f"Registry contract_ref target does not exist: {contract_ref}",
            )

    providers = nested_get(reason, "providers", default=[])
    if not isinstance(providers, list):
        report.error(check, "Registry '&reason.providers' must be array")
        return data

    graphonomous = None
    for pvd in providers:
        if isinstance(pvd, dict) and pvd.get("id") == "graphonomous":
            graphonomous = pvd
            break

    if not graphonomous:
        report.error(check, "Registry missing graphonomous provider under '&reason'")
        return data

    p_subtypes = set(str(s) for s in graphonomous.get("subtypes", []) if isinstance(s, str))
    for needed in ("deliberate", "attend"):
        if needed not in p_subtypes:
            report.error(check, f"graphonomous provider missing subtype '{needed}'")

    md = graphonomous.get("metadata", {})
    if isinstance(md, dict):
        tiers = set(str(t) for t in md.get("model_tiers", []) if isinstance(t, str))
        missing_tiers = MODEL_TIERS - tiers
        if missing_tiers:
            report.warn(
                check,
                f"graphonomous metadata.model_tiers missing {sorted(missing_tiers)}",
            )

        refs = normalize_refs(md.get("contract_refs", []))
        expected_refs = {
            "/contracts/v0.1.0/reason.deliberate.contract.json",
            "/contracts/v0.1.0/reason.attend.contract.json",
        }
        missing_refs = expected_refs - refs
        if missing_refs:
            report.error(
                check,
                f"graphonomous metadata.contract_refs missing {sorted(missing_refs)}",
            )
    else:
        report.error(check, "graphonomous metadata missing or not object")

    return data


def check_schema_contract_tokens(root: Path, report: Report) -> Dict[str, Any]:
    check = "capability-contract-schema"
    p = root / "protocol/schema/v0.1.0/capability-contract.schema.json"
    if not p.exists():
        return {}

    data = read_json(p)
    text = json.dumps(data, ensure_ascii=False)

    # Ensure capability examples are present
    for cap in CAPABILITIES:
        if cap not in text:
            report.error(check, f"Schema/examples missing capability token: {cap}")

    # Ensure important type tokens are represented somewhere in schema/docs/examples
    for token in TYPE_TOKENS:
        if token not in text:
            report.error(check, f"Schema missing type token mention: {token}")

    # Validate root fields are constrained
    required = set(data.get("required", []))
    for req in ("capability", "operations", "accepts_from", "feeds_into"):
        if req not in required:
            report.error(check, f"Schema.required missing '{req}'")

    return data


def check_text_surfaces(root: Path, report: Report) -> None:
    check = "text-surfaces"

    targets = {
        "SPEC.md": root / "SPEC.md",
        "README.md": root / "README.md",
        "site/protocol.html": root / "site/protocol.html",
        "protocol/schema/index.html": root / "protocol/schema/index.html",
        "protocol/registry/index.html": root / "protocol/registry/index.html",
        "docs/registry/reason.deliberate.md": root / "docs/registry/reason.deliberate.md",
        "docs/registry/reason.attend.md": root / "docs/registry/reason.attend.md",
    }

    texts: Dict[str, str] = {}
    for name, path in targets.items():
        if path.exists():
            texts[name] = read_text(path)

    # Core capability presence
    for name in ("SPEC.md", "README.md", "site/protocol.html"):
        if name in texts:
            missing = has_all_tokens(texts[name], CAPABILITIES)
            if missing:
                report.error(check, f"{name} missing capabilities: {sorted(missing)}")

    # Model tier parity:
    # - SPEC is normative and should enumerate all supported tiers.
    # - README is explanatory and only needs to remain aligned conceptually.
    if "SPEC.md" in texts:
        missing_tiers = has_all_tokens(texts["SPEC.md"], MODEL_TIERS)
        if missing_tiers:
            report.error(check, f"SPEC.md missing model tiers: {sorted(missing_tiers)}")

    if "README.md" in texts:
        readme_text = texts["README.md"]
        if "model_tier" not in readme_text:
            report.warn(check, "README.md missing 'model_tier' mention")
        elif not any(token_present(readme_text, tier) for tier in MODEL_TIERS):
            report.warn(
                check,
                "README.md references model_tier but does not include any known tier token",
            )

    # TYPE tokens where expected
    if "SPEC.md" in texts:
        missing = has_all_tokens(texts["SPEC.md"], TYPE_TOKENS)
        if missing:
            report.error(check, f"SPEC.md missing type tokens: {sorted(missing)}")

    # Site snippet should include autonomy snippet fields
    if "site/protocol.html" in texts:
        t = texts["site/protocol.html"]
        for token in ("model_tier", "heartbeat_seconds"):
            if token not in t:
                report.warn(check, f"site/protocol.html missing snippet token '{token}'")

    # Schema/registry landing pages should mention deliberate + attend
    for name in ("protocol/schema/index.html", "protocol/registry/index.html"):
        if name in texts:
            missing = has_all_tokens(texts[name], CAPABILITIES)
            if missing:
                report.error(check, f"{name} missing capabilities: {sorted(missing)}")

    # Registry docs pages should mention their capability
    if "docs/registry/reason.deliberate.md" in texts:
        if "&reason.deliberate" not in texts["docs/registry/reason.deliberate.md"]:
            report.warn(
                check,
                "docs/registry/reason.deliberate.md missing '&reason.deliberate' literal",
            )
    if "docs/registry/reason.attend.md" in texts:
        if "&reason.attend" not in texts["docs/registry/reason.attend.md"]:
            report.warn(
                check,
                "docs/registry/reason.attend.md missing '&reason.attend' literal",
            )


def check_contract_registry_crosslinks(
    root: Path,
    contracts: Dict[str, Dict[str, Any]],
    registry: Dict[str, Any],
    report: Report,
) -> None:
    check = "crosslinks"

    if not contracts or not registry:
        return

    reason_subtypes = nested_get(registry, "&reason", "subtypes", default={})
    if not isinstance(reason_subtypes, dict):
        return

    mapping = {
        "&reason.deliberate": "deliberate",
        "&reason.attend": "attend",
    }

    for cap, subtype in mapping.items():
        c = contracts.get(cap)
        s = reason_subtypes.get(subtype)
        if not c or not isinstance(s, dict):
            continue

        cref = s.get("contract_ref")
        expected = f"/contracts/v0.1.0/{cap.replace('&reason.', 'reason.')}.contract.json"
        if cref != expected:
            report.error(
                check,
                f"Registry {subtype}.contract_ref not aligned with contract path "
                f"(expected {expected}, got {cref!r})",
            )

        # Ensure operation names in docs are consistent with contract ops
        ops = set((c.get("operations") or {}).keys())
        subtype_ops = set(s.get("ops", [])) if isinstance(s.get("ops"), list) else set()
        if ops and subtype_ops and not ops.issubset(subtype_ops):
            report.warn(
                check,
                f"Registry '&reason.{subtype}.ops' does not fully cover contract ops: "
                f"contract={sorted(ops)} registry={sorted(subtype_ops)}",
            )


def print_human_report(report: Report, strict: bool) -> None:
    if report.findings:
        for f in report.findings:
            marker = "ERROR" if f.kind == "error" else "WARN "
            print(f"[{marker}] {f.check}: {f.message}")

    print()
    print(f"Errors:   {len(report.errors)}")
    print(f"Warnings: {len(report.warnings)}")
    if len(report.errors) == 0 and (len(report.warnings) == 0 or not strict):
        print("Status:   PASS")
    elif len(report.errors) == 0 and strict and len(report.warnings) > 0:
        print("Status:   FAIL (strict mode: warnings treated as failures)")
    else:
        print("Status:   FAIL")


def print_json_report(report: Report, strict: bool) -> None:
    payload = {
        "status": (
            "pass"
            if len(report.errors) == 0 and (len(report.warnings) == 0 or not strict)
            else "fail"
        ),
        "errors": [
            {"check": f.check, "message": f.message}
            for f in report.errors
        ],
        "warnings": [
            {"check": f.check, "message": f.message}
            for f in report.warnings
        ],
        "counts": {"errors": len(report.errors), "warnings": len(report.warnings)},
        "strict": strict,
    }
    print(json.dumps(payload, indent=2, ensure_ascii=False))


def resolve_root(explicit_root: Optional[str]) -> Path:
    if explicit_root:
        return Path(explicit_root).expanduser().resolve()
    # tools/check_protocol_parity.py -> parent is tools/, parent.parent is AmpersandBoxDesign/
    return Path(__file__).resolve().parent.parent


def parse_args(argv: List[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Check protocol parity across SPEC/schema/contracts/registry/site snippets."
    )
    p.add_argument(
        "--root",
        default=None,
        help="Path to AmpersandBoxDesign root (defaults to script parent root).",
    )
    p.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as failures.",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON report.",
    )
    return p.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    root = resolve_root(args.root)

    report = Report()

    if not root.exists():
        report.error("setup", f"Root path does not exist: {root}")
    else:
        check_required_files(root, report)
        contracts = check_contracts(root, report)
        registry = check_registry(root, report)
        _schema = check_schema_contract_tokens(root, report)
        check_text_surfaces(root, report)
        check_contract_registry_crosslinks(root, contracts, registry, report)

    if args.json:
        print_json_report(report, args.strict)
    else:
        print(f"Protocol parity check root: {root}")
        print_human_report(report, args.strict)

    if report.errors:
        return 1
    if args.strict and report.warnings:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
