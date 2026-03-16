#!/usr/bin/env python3
"""
CLI entrypoint for the ampersand_protocol Python SDK.

Commands:
  - ampersand validate <file>
  - ampersand compose <file1> [file2...]
  - ampersand generate mcp <file> [--format zed|generic] [-o|--output <path>]

All command results are emitted as structured JSON:
  - success to stdout
  - errors to stderr
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List

from .compose import compose_documents, normalize_capabilities
from .mcp import generate_mcp_config
from .validator import load_json_file, validate_file


def _write_json(payload: Dict[str, Any], *, error: bool = False) -> None:
    stream = sys.stderr if error else sys.stdout
    stream.write(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def _ok(payload: Dict[str, Any]) -> int:
    _write_json(payload, error=False)
    return 0


def _err(
    error_kind: str,
    errors: List[str] | str,
    *,
    command: str | None = None,
    extra: Dict[str, Any] | None = None,
    exit_code: int = 1,
) -> int:
    if isinstance(errors, str):
        normalized = [errors]
    else:
        normalized = [str(e) for e in errors]

    payload: Dict[str, Any] = {
        "status": "error",
        "error": error_kind,
        "errors": normalized,
    }

    if command:
        payload["command"] = command

    if extra:
        payload.update(extra)

    _write_json(payload, error=True)
    return exit_code


def _cmd_validate(args: argparse.Namespace) -> int:
    path = args.file
    result = validate_file(path)

    if not result.ok:
        return _err(
            "validation_failed",
            result.errors,
            command="validate",
            extra={"file": path},
        )

    doc = result.document
    capabilities = doc.get("capabilities", {}) if isinstance(doc, dict) else {}

    return _ok(
        {
            "command": "validate",
            "status": "ok",
            "valid": True,
            "file": path,
            "agent": doc.get("agent"),
            "version": doc.get("version"),
            "schema": doc.get("$schema"),
            "capability_count": len(capabilities) if isinstance(capabilities, dict) else 0,
        }
    )


def _cmd_compose(args: argparse.Namespace) -> int:
    files: List[str] = args.files

    try:
        composed = compose_documents(files)
    except Exception as exc:  # pragma: no cover - defensive error boundary
        return _err(
            "compose_failed",
            str(exc),
            command="compose",
            extra={"files": files},
        )

    if not composed.ok:
        return _err(
            "compose_failed",
            composed.errors,
            command="compose",
            extra={"files": files},
        )

    merged_doc = composed.document
    capabilities = normalize_capabilities(merged_doc)

    if len(files) == 1:
        source = load_json_file(files[0]).document
        return _ok(
            {
                "command": "compose",
                "status": "ok",
                "file": files[0],
                "agent": source.get("agent") if isinstance(source, dict) else None,
                "version": source.get("version") if isinstance(source, dict) else None,
                "capabilities": capabilities,
                "capability_count": len(capabilities),
                "composed": merged_doc.get("capabilities", {}),
            }
        )

    agents: List[str] = []
    versions: List[str] = []

    for path in files:
        loaded = load_json_file(path)
        if loaded.ok and isinstance(loaded.document, dict):
            agent = loaded.document.get("agent")
            version = loaded.document.get("version")
            if isinstance(agent, str):
                agents.append(agent)
            if isinstance(version, str):
                versions.append(version)

    return _ok(
        {
            "command": "compose",
            "status": "ok",
            "files": files,
            "file_count": len(files),
            "agents": sorted(set(agents)),
            "versions": sorted(set(versions)),
            "capabilities": capabilities,
            "capability_count": len(capabilities),
            "composed": merged_doc.get("capabilities", {}),
        }
    )


def _cmd_generate_mcp(args: argparse.Namespace) -> int:
    declaration_path = args.file
    output_path = args.output
    format_name = args.format

    validated = validate_file(declaration_path)
    if not validated.ok:
        return _err(
            "mcp_generation_failed",
            validated.errors,
            command="generate",
            extra={"target": "mcp", "file": declaration_path},
        )

    try:
        mcp_result = generate_mcp_config(validated.document, format=format_name)
    except Exception as exc:  # pragma: no cover - defensive error boundary
        return _err(
            "mcp_generation_failed",
            str(exc),
            command="generate",
            extra={"target": "mcp", "file": declaration_path, "format": format_name},
        )

    if output_path:
        out = Path(output_path)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(mcp_result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return _ok(
            {
                "command": "generate",
                "target": "mcp",
                "status": "ok",
                "file": declaration_path,
                "format": format_name,
                "output": str(out),
                "config": mcp_result,
            }
        )

    return _ok(
        {
            "command": "generate",
            "target": "mcp",
            "status": "ok",
            "file": declaration_path,
            "format": format_name,
            "config": mcp_result,
        }
    )


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ampersand",
        description="Ampersand Protocol Python SDK CLI",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    p_validate = subparsers.add_parser("validate", help="Validate an ampersand declaration file")
    p_validate.add_argument("file", help="Path to ampersand.json file")
    p_validate.set_defaults(handler=_cmd_validate)

    p_compose = subparsers.add_parser(
        "compose",
        help="Compose one or more declaration files into a merged capability set",
    )
    p_compose.add_argument("files", nargs="+", help="One or more ampersand declaration files")
    p_compose.set_defaults(handler=_cmd_compose)

    p_generate = subparsers.add_parser(
        "generate",
        help="Generate downstream artifacts from a declaration",
    )
    generate_subparsers = p_generate.add_subparsers(dest="generate_target", required=True)

    p_generate_mcp = generate_subparsers.add_parser(
        "mcp",
        help="Generate MCP config dict from a declaration",
    )
    p_generate_mcp.add_argument("file", help="Path to ampersand declaration file")
    p_generate_mcp.add_argument(
        "--format",
        choices=("zed", "generic"),
        default="zed",
        help="Output format key style",
    )
    p_generate_mcp.add_argument(
        "-o",
        "--output",
        help="Optional output file path for generated config JSON",
    )
    p_generate_mcp.set_defaults(handler=_cmd_generate_mcp)

    return parser


def main(argv: List[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    handler = getattr(args, "handler", None)
    if handler is None:
        return _err("invalid_arguments", "no command handler selected", command=str(args.command))

    return int(handler(args))


if __name__ == "__main__":
    raise SystemExit(main())
