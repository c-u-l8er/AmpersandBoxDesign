"""
Ampersand Protocol MCP config generator.

This module generates MCP client/server configuration blocks from an
`ampersand.json` declaration, with optional registry-backed `provider: "auto"`
resolution.

Public API:
    - generate_mcp_config(document, ...)
    - generate_mcp_config_file(path, ...)
    - to_json(manifest, pretty=True)
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Callable, Dict, List, Mapping, Optional, Tuple
import json


ProviderResolver = Callable[[str, List[Dict[str, Any]], Mapping[str, Any]], Dict[str, Any]]


def default_registry_path() -> Path:
    """
    Return the default path to the canonical registry artifact.
    """
    return Path(__file__).resolve().parents[5] / "registry" / "v0.1.0" / "capabilities.registry.json"


def load_registry(path: Optional[str | Path] = None) -> Dict[str, Any]:
    """
    Load registry JSON from path or default location.
    """
    registry_path = Path(path) if path is not None else default_registry_path()
    with registry_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError("Registry artifact must be a JSON object")
    return data


def default_provider_resolvers() -> Dict[str, ProviderResolver]:
    """
    Built-in provider resolvers.

    - graphonomous: stdio via npx graphonomous
    - ticktickclock: stdio via npx @ampersand-protocol/ticktickclock-mcp
    """
    return {
        "graphonomous": _resolve_graphonomous,
        "ticktickclock": _resolve_ticktickclock,
    }


def generate_mcp_config_file(
    declaration_path: str | Path,
    *,
    format: str = "zed",
    strict: bool = False,
    include_metadata: bool = True,
    registry: Optional[Mapping[str, Any]] = None,
    registry_path: Optional[str | Path] = None,
    provider_resolvers: Optional[Mapping[str, ProviderResolver]] = None,
    graphonomous_db_path: str = "~/.graphonomous/knowledge.db",
    graphonomous_embedder_backend: str = "fallback",
    graphonomous_env: Optional[Mapping[str, str]] = None,
) -> Dict[str, Any]:
    """
    Read declaration file and generate MCP manifest.
    """
    with Path(declaration_path).open("r", encoding="utf-8") as f:
        document = json.load(f)
    return generate_mcp_config(
        document,
        format=format,
        strict=strict,
        include_metadata=include_metadata,
        registry=registry,
        registry_path=registry_path,
        provider_resolvers=provider_resolvers,
        graphonomous_db_path=graphonomous_db_path,
        graphonomous_embedder_backend=graphonomous_embedder_backend,
        graphonomous_env=graphonomous_env,
    )


def generate_mcp_config(
    document: Mapping[str, Any],
    *,
    format: str = "zed",
    strict: bool = False,
    include_metadata: bool = True,
    registry: Optional[Mapping[str, Any]] = None,
    registry_path: Optional[str | Path] = None,
    provider_resolvers: Optional[Mapping[str, ProviderResolver]] = None,
    graphonomous_db_path: str = "~/.graphonomous/knowledge.db",
    graphonomous_embedder_backend: str = "fallback",
    graphonomous_env: Optional[Mapping[str, str]] = None,
) -> Dict[str, Any]:
    """
    Generate an MCP manifest from an ampersand declaration dict.

    Parameters
    ----------
    document:
        Parsed ampersand declaration object.
    format:
        "zed" => config root key `context_servers`
        "generic" => config root key `mcpServers`
    strict:
        If True, unresolved providers raise ValueError.
    include_metadata:
        If True, include governance/provenance/registry metadata in manifest.
    registry / registry_path:
        Optional capability registry object/path for auto-resolution and metadata.
    provider_resolvers:
        Override/extend built-in provider resolvers.
    """
    if not isinstance(document, Mapping):
        raise ValueError("document must be a mapping/object")

    capabilities = document.get("capabilities", {})
    if not isinstance(capabilities, Mapping):
        raise ValueError("document.capabilities must be an object")

    cap_registry: Dict[str, Any] = {}
    if registry is not None:
        cap_registry = dict(registry)
    else:
        try:
            cap_registry = load_registry(registry_path)
        except Exception:
            # Registry is optional at runtime; unresolved metadata will reflect missing info.
            cap_registry = {}

    base_resolvers = default_provider_resolvers()
    merged_resolvers: Dict[str, ProviderResolver] = dict(base_resolvers)
    if provider_resolvers:
        merged_resolvers.update(provider_resolvers)

    bindings = _normalize_bindings(capabilities)
    effective_bindings, unresolved_auto = _expand_auto_bindings(bindings, cap_registry)

    grouped: Dict[str, List[Dict[str, Any]]] = {}
    for binding in effective_bindings:
        grouped.setdefault(binding["provider"], []).append(binding)

    resolved_servers: Dict[str, Dict[str, Any]] = {}
    unresolved: List[Dict[str, Any]] = list(unresolved_auto)

    provider_index = _registry_provider_index(cap_registry)

    resolver_opts = {
        "graphonomous_db_path": graphonomous_db_path,
        "graphonomous_embedder_backend": graphonomous_embedder_backend,
        "graphonomous_env": dict(graphonomous_env or {}),
    }

    for provider_id in sorted(grouped.keys()):
        provider_bindings = grouped[provider_id]
        resolver = merged_resolvers.get(provider_id)

        if resolver is not None:
            server_config = resolver(provider_id, provider_bindings, resolver_opts)
            # keep only client-launch-relevant keys in final config
            cleaned = _normalize_server_config(server_config)
            resolved_servers[provider_id] = cleaned
            continue

        provider_meta = provider_index.get(provider_id)
        unresolved_entry = {
            "provider": provider_id,
            "capabilities": sorted([b["capability"] for b in provider_bindings]),
            "reason": (
                "provider is published in registry but no local MCP resolver is implemented"
                if provider_meta is not None
                else "no MCP resolver registered for provider"
            ),
            "published_in_registry": provider_meta is not None,
        }
        if provider_meta is not None:
            unresolved_entry["registry_provider"] = provider_meta
        unresolved.append(unresolved_entry)

    if strict and unresolved:
        msgs = [f'unresolved provider {u["provider"]}: {u["reason"]}' for u in unresolved]
        raise ValueError("; ".join(msgs))

    root_key = "mcpServers" if format == "generic" else "context_servers"

    manifest: Dict[str, Any] = {
        "agent": document.get("agent"),
        "version": document.get("version"),
        "format": root_key,
        "config": {root_key: resolved_servers},
        "providers": _provider_summary(effective_bindings, resolved_servers, cap_registry),
        "unresolved_providers": unresolved,
    }

    if include_metadata:
        if "governance" in document:
            manifest["governance"] = document.get("governance")
        if "provenance" in document:
            manifest["provenance"] = document.get("provenance")

        reg_meta = _registry_metadata(cap_registry)
        if reg_meta:
            manifest["registry"] = reg_meta

    return manifest


def to_json(manifest: Mapping[str, Any], *, pretty: bool = True) -> str:
    """
    Encode generated MCP manifest to JSON.
    """
    return json.dumps(manifest, indent=2 if pretty else None, sort_keys=False, ensure_ascii=False)


# -----------------------------
# Internals
# -----------------------------


def _normalize_bindings(capabilities: Mapping[str, Any]) -> List[Dict[str, Any]]:
    bindings: List[Dict[str, Any]] = []
    for capability, binding in capabilities.items():
        if not isinstance(binding, Mapping):
            continue
        provider = binding.get("provider")
        if not isinstance(provider, str):
            continue
        bindings.append(
            {
                "capability": str(capability),
                "provider": provider,
                "config": binding.get("config") if isinstance(binding.get("config"), Mapping) else {},
                "need": binding.get("need"),
            }
        )
    bindings.sort(key=lambda b: (b["provider"], b["capability"]))
    return bindings


def _expand_auto_bindings(
    bindings: List[Dict[str, Any]],
    registry: Mapping[str, Any],
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    resolved: List[Dict[str, Any]] = []
    unresolved: List[Dict[str, Any]] = []

    for binding in bindings:
        if binding["provider"] != "auto":
            resolved.append(binding)
            continue

        candidates = _providers_for_capability(registry, binding["capability"])
        candidates = [p for p in candidates if isinstance(p.get("id"), str)]
        candidates.sort(key=lambda p: p["id"])

        if not candidates:
            unresolved.append(
                {
                    "provider": "auto",
                    "capabilities": [binding["capability"]],
                    "reason": f'no registry provider found for capability {binding["capability"]}',
                    "published_in_registry": False,
                }
            )
            continue

        selected = candidates[0]
        auto_resolved = dict(binding)
        auto_resolved["provider"] = selected["id"]
        auto_resolved["provider_resolution"] = {
            "status": "resolved-from-registry",
            "provider": "auto",
            "selected_provider": selected["id"],
            "protocol": selected.get("protocol"),
            "transport": selected.get("transport"),
            "url": selected.get("url"),
        }
        resolved.append(auto_resolved)

    resolved.sort(key=lambda b: (b["provider"], b["capability"]))
    return resolved, unresolved


def _providers_for_capability(registry: Mapping[str, Any], capability: str) -> List[Dict[str, Any]]:
    parsed = _parse_capability(capability)
    if parsed is None:
        return []

    primitive, subtype = parsed
    primitive_entry = registry.get(primitive)
    if not isinstance(primitive_entry, Mapping):
        return []

    providers = primitive_entry.get("providers", [])
    if not isinstance(providers, list):
        return []

    if subtype is None:
        return [p for p in providers if isinstance(p, dict)]

    filtered: List[Dict[str, Any]] = []
    for provider in providers:
        if not isinstance(provider, dict):
            continue
        subtypes = provider.get("subtypes", [])
        if isinstance(subtypes, list) and subtype in subtypes:
            filtered.append(provider)
    return filtered


def _parse_capability(capability: str) -> Optional[Tuple[str, Optional[str]]]:
    if not capability or not capability.startswith("&"):
        return None
    parts = capability.split(".")
    primitive = parts[0]
    subtype = parts[1] if len(parts) > 1 else None
    return primitive, subtype


def _registry_provider_index(registry: Mapping[str, Any]) -> Dict[str, Dict[str, Any]]:
    index: Dict[str, Dict[str, Any]] = {}
    for key, value in registry.items():
        if not isinstance(key, str) or not key.startswith("&"):
            continue
        if not isinstance(value, Mapping):
            continue
        providers = value.get("providers", [])
        if not isinstance(providers, list):
            continue
        for provider in providers:
            if not isinstance(provider, dict):
                continue
            provider_id = provider.get("id")
            if isinstance(provider_id, str) and provider_id not in index:
                index[provider_id] = provider
    return index


def _provider_summary(
    bindings: List[Dict[str, Any]],
    resolved_servers: Mapping[str, Any],
    registry: Mapping[str, Any],
) -> Dict[str, Dict[str, Any]]:
    summary: Dict[str, Dict[str, Any]] = {}
    provider_index = _registry_provider_index(registry)

    grouped: Dict[str, List[str]] = {}
    for binding in bindings:
        grouped.setdefault(binding["provider"], []).append(binding["capability"])

    for provider_id in sorted(grouped.keys()):
        caps = sorted(set(grouped[provider_id]))
        reg_provider = provider_index.get(provider_id)
        entry: Dict[str, Any] = {
            "server_name": provider_id if provider_id in resolved_servers else None,
            "capabilities": caps,
            "published_in_registry": reg_provider is not None,
        }
        if reg_provider is not None:
            entry["protocol"] = reg_provider.get("protocol")
            entry["transport"] = reg_provider.get("transport")
            entry["status"] = reg_provider.get("status")
            if reg_provider.get("url") is not None:
                entry["url"] = reg_provider.get("url")
        summary[provider_id] = {k: v for k, v in entry.items() if v is not None}
    return summary


def _registry_metadata(registry: Mapping[str, Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    if not isinstance(registry, Mapping) or not registry:
        return out
    if isinstance(registry.get("registry"), str):
        out["id"] = registry["registry"]
    if isinstance(registry.get("version"), str):
        out["version"] = registry["version"]
    if isinstance(registry.get("generated_at"), str):
        out["generated_at"] = registry["generated_at"]
    return out


def _normalize_server_config(server: Mapping[str, Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    if "command" in server:
        out["command"] = server.get("command")
    out["args"] = server.get("args", []) if isinstance(server.get("args", []), list) else []
    out["env"] = server.get("env", {}) if isinstance(server.get("env", {}), Mapping) else {}
    if server.get("transport") is not None:
        out["transport"] = server.get("transport")
    if server.get("url") is not None:
        out["url"] = server.get("url")
    return out


def _resolve_graphonomous(
    provider_id: str,
    bindings: List[Dict[str, Any]],
    opts: Mapping[str, Any],
) -> Dict[str, Any]:
    caps = sorted([b["capability"] for b in bindings])
    env = {
        "GRAPHONOMOUS_EMBEDDING_MODEL": "sentence-transformers/all-MiniLM-L6-v2",
    }
    env.update(dict(opts.get("graphonomous_env", {})))
    return {
        "provider": provider_id,
        "command": "npx",
        "args": [
            "-y",
            "graphonomous",
            "--db",
            opts.get("graphonomous_db_path", "~/.graphonomous/knowledge.db"),
            "--embedder-backend",
            opts.get("graphonomous_embedder_backend", "fallback"),
        ],
        "env": env,
        "transport": "stdio",
        "capabilities": caps,
    }


def _resolve_ticktickclock(
    provider_id: str,
    bindings: List[Dict[str, Any]],
    opts: Mapping[str, Any],
) -> Dict[str, Any]:
    del opts
    caps = sorted([b["capability"] for b in bindings])
    return {
        "provider": provider_id,
        "command": "npx",
        "args": ["-y", "@ampersand-protocol/ticktickclock-mcp"],
        "env": {},
        "transport": "stdio",
        "capabilities": caps,
    }
