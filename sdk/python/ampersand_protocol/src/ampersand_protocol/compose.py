"""Capability composition and normalization helpers for ampersand declarations.

This module provides deterministic, set-like behavior for capability maps:

- normalize capability identifiers into a sorted list
- compose one or more capability maps/documents
- detect conflicting bindings
- expose lightweight ACI property checks
"""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple

CapabilityId = str
CapabilityBinding = Dict[str, Any]
CapabilityMap = Dict[CapabilityId, CapabilityBinding]
Document = Mapping[str, Any]


@dataclass(frozen=True)
class ComposeConflict:
    """Structured conflict information for a capability merge failure."""

    capability: str
    existing: Mapping[str, Any]
    incoming: Mapping[str, Any]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "capability": self.capability,
            "existing": dict(self.existing),
            "incoming": dict(self.incoming),
        }


@dataclass(frozen=True)
class ComposeResult:
    """Normalized success/error wrapper for compose operations."""

    ok: bool
    errors: List[str]
    document: Optional[Dict[str, Any]] = None
    conflict: Optional[ComposeConflict] = None

    def to_dict(self) -> Dict[str, Any]:
        payload: Dict[str, Any] = {"ok": self.ok, "errors": self.errors}
        if self.document is not None:
            payload["document"] = self.document
        if self.conflict is not None:
            payload["conflict"] = self.conflict.to_dict()
        return payload


class ComposeError(ValueError):
    """Raised when composition inputs are invalid or conflicting."""

    def __init__(self, message: str, *, conflict: Optional[ComposeConflict] = None) -> None:
        super().__init__(message)
        self.conflict = conflict


def identity() -> CapabilityMap:
    """Return the identity capability map for composition."""
    return {}


def normalize_capabilities(input_value: Mapping[str, Any]) -> List[str]:
    """Return sorted capability identifiers from a declaration or capability map."""
    capabilities = _capabilities_from_input(input_value)
    return sorted(set(capabilities.keys()))


def compose(inputs: Sequence[Mapping[str, Any]]) -> CapabilityMap:
    """Compose one or more declarations/capability maps into a single capability map.

    Rules:
    - disjoint keys merge directly
    - identical duplicate bindings collapse cleanly
    - conflicting bindings for same key raise ComposeError
    """
    merged: CapabilityMap = {}

    for input_value in inputs:
        incoming = _capabilities_from_input(input_value)
        merged = merge(merged, incoming)

    return merged


def compose_capabilities(inputs: Sequence[Mapping[str, Any]]) -> ComposeResult:
    """
    Compose one or more declarations/capability maps and return a result wrapper.

    Returns:
      ComposeResult(ok=True, document={"capabilities": ..., "capability_count": ...})
      ComposeResult(ok=False, errors=[...], conflict=...)
    """
    try:
        merged = compose(inputs)
    except ComposeError as exc:
        return ComposeResult(
            ok=False,
            errors=[str(exc)],
            conflict=exc.conflict,
        )

    return ComposeResult(
        ok=True,
        errors=[],
        document={
            "capabilities": merged,
            "capability_count": len(merged),
            "normalized": sorted(merged.keys()),
        },
    )


def compose_documents(paths: Sequence[str | Path]) -> ComposeResult:
    """
    Load declaration JSON files, compose their capabilities, and return result wrapper.
    """
    documents: List[Dict[str, Any]] = []

    for raw_path in paths:
        path = Path(raw_path).expanduser().resolve()
        try:
            with path.open("r", encoding="utf-8") as f:
                decoded = json.load(f)
        except OSError as exc:
            return ComposeResult(
                ok=False,
                errors=[f"Unable to read declaration at {path}: {exc}"],
            )
        except json.JSONDecodeError as exc:
            return ComposeResult(
                ok=False,
                errors=[f"Unable to parse declaration at {path}: {exc}"],
            )

        if not isinstance(decoded, dict):
            return ComposeResult(
                ok=False,
                errors=[f"Declaration at {path} must decode to a JSON object"],
            )

        documents.append(decoded)

    return compose_capabilities(documents)


def merge(left: Mapping[str, Any], right: Mapping[str, Any]) -> CapabilityMap:
    """Merge two capability maps with conflict detection."""
    if not isinstance(left, Mapping) or not isinstance(right, Mapping):
        raise ComposeError("left and right must be capability maps")

    merged: CapabilityMap = {str(k): _as_binding(v, context="left map") for k, v in left.items()}

    for capability, incoming_binding_raw in right.items():
        capability_id = _validate_capability_key(capability)
        incoming_binding = _as_binding(incoming_binding_raw, context=f"capability {capability_id}")

        if capability_id not in merged:
            merged[capability_id] = incoming_binding
            continue

        existing_binding = merged[capability_id]
        if _bindings_equal(existing_binding, incoming_binding):
            continue

        conflict = ComposeConflict(
            capability=capability_id,
            existing=existing_binding,
            incoming=incoming_binding,
        )
        raise ComposeError(
            f"conflicting binding for capability {capability_id}",
            conflict=conflict,
        )

    return merged


def aci_equivalent(left: Mapping[str, Any], right: Mapping[str, Any]) -> bool:
    """Check whether two declarations are equivalent under normalization + bindings."""
    try:
        left_caps = _capabilities_from_input(left)
        right_caps = _capabilities_from_input(right)
    except ComposeError:
        return False

    if sorted(left_caps.keys()) != sorted(right_caps.keys()):
        return False

    return _bindings_equal(left_caps, right_caps)


def commutative(left: Mapping[str, Any], right: Mapping[str, Any]) -> bool:
    """Check commutativity for two composition inputs."""
    try:
        return compose([left, right]) == compose([right, left])
    except ComposeError:
        return False


def associative(
    left: Mapping[str, Any],
    middle: Mapping[str, Any],
    right: Mapping[str, Any],
) -> bool:
    """Check associativity for three composition inputs."""
    try:
        grouped_left = compose([compose([left, middle]), right])
        grouped_right = compose([left, compose([middle, right])])
        return grouped_left == grouped_right
    except ComposeError:
        return False


def idempotent(input_value: Mapping[str, Any]) -> bool:
    """Check idempotency for a composition input."""
    try:
        return compose([input_value]) == compose([input_value, input_value])
    except ComposeError:
        return False


def has_identity(input_value: Mapping[str, Any]) -> bool:
    """Check identity law for a composition input."""
    try:
        one = compose([input_value])
        return compose([identity(), input_value]) == one and compose([input_value, identity()]) == one
    except ComposeError:
        return False


def _capabilities_from_input(input_value: Mapping[str, Any]) -> CapabilityMap:
    """Extract and validate a capability map from either:
    - full document: {"capabilities": {...}}
    - raw capability map: {"&memory.graph": {...}, ...}
    """
    if not isinstance(input_value, Mapping):
        raise ComposeError("composition input must be a mapping")

    if "capabilities" in input_value:
        capabilities = input_value.get("capabilities")
        if not isinstance(capabilities, Mapping):
            raise ComposeError("document.capabilities must be a mapping")
        return _validate_capability_map(capabilities)

    return _validate_capability_map(input_value)


def _validate_capability_map(value: Mapping[str, Any]) -> CapabilityMap:
    if not isinstance(value, Mapping):
        raise ComposeError("capability map must be a mapping")

    normalized: CapabilityMap = {}
    for raw_key, raw_binding in value.items():
        capability_id = _validate_capability_key(raw_key)
        normalized[capability_id] = _as_binding(
            raw_binding,
            context=f"capability {capability_id}",
        )
    return normalized


def _validate_capability_key(value: Any) -> str:
    if not isinstance(value, str) or value.strip() == "":
        raise ComposeError(f"capability key must be a non-empty string, got {value!r}")
    if not value.startswith("&"):
        raise ComposeError(f"capability key must start with '&', got {value!r}")
    return value


def _as_binding(value: Any, *, context: str) -> CapabilityBinding:
    if not isinstance(value, Mapping):
        raise ComposeError(f"{context} binding must be a mapping")
    return {str(k): v for k, v in value.items()}


def _bindings_equal(left: Any, right: Any) -> bool:
    return _stable_primitive(left) == _stable_primitive(right)


def _stable_primitive(value: Any) -> Any:
    """Convert nested values into stable comparable primitives."""
    if isinstance(value, Mapping):
        return tuple((str(k), _stable_primitive(v)) for k, v in sorted(value.items(), key=lambda item: str(item[0])))
    if isinstance(value, list):
        return tuple(_stable_primitive(v) for v in value)
    if isinstance(value, tuple):
        return tuple(_stable_primitive(v) for v in value)
    return value


__all__ = [
    "CapabilityBinding",
    "CapabilityMap",
    "ComposeConflict",
    "ComposeError",
    "ComposeResult",
    "aci_equivalent",
    "associative",
    "commutative",
    "compose",
    "compose_capabilities",
    "compose_documents",
    "has_identity",
    "idempotent",
    "identity",
    "merge",
    "normalize_capabilities",
]
