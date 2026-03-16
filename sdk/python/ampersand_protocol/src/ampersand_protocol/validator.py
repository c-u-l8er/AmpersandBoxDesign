"""
Schema validation helpers for ampersand.json declarations.

This module provides a minimal, explicit API for loading the bundled protocol
schema and validating decoded documents or on-disk JSON files.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any, Iterable, Optional

try:
    from jsonschema import Draft202012Validator
except Exception as exc:  # pragma: no cover - import-time guard
    raise RuntimeError(
        "The 'jsonschema' package is required for ampersand schema validation. "
        "Install it with: pip install jsonschema"
    ) from exc


@dataclass(frozen=True)
class ValidationResult:
    """Normalized validation result payload."""

    ok: bool
    errors: list[str]
    document: Optional[dict[str, Any]] = None

    def to_dict(self) -> dict[str, Any]:
        payload: dict[str, Any] = {"ok": self.ok, "errors": self.errors}
        if self.document is not None:
            payload["document"] = self.document
        return payload


def _module_root() -> Path:
    """
    Return package module root.

    Expected location of this file:
      .../src/ampersand_protocol/validator.py
    """
    return Path(__file__).resolve().parent


def default_schema_path() -> Path:
    """Return bundled ampersand schema path."""
    return _module_root() / "schema" / "ampersand.schema.json"


def read_json_file(path: str | Path, *, label: str = "JSON file") -> ValidationResult:
    """Read and decode JSON from disk."""
    file_path = Path(path).expanduser().resolve()

    try:
        raw = file_path.read_text(encoding="utf-8")
    except OSError as exc:
        return ValidationResult(
            ok=False,
            errors=[f"Unable to read {label} at {file_path}: {exc}"],
        )

    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as exc:
        return ValidationResult(
            ok=False,
            errors=[f"Unable to parse {label} at {file_path}: {exc}"],
        )

    if not isinstance(decoded, dict):
        return ValidationResult(
            ok=False,
            errors=[f"{label} at {file_path} must decode to a JSON object"],
        )

    return ValidationResult(ok=True, errors=[], document=decoded)


def load_json_file(path: str | Path, *, label: str = "JSON file") -> ValidationResult:
    """
    Compatibility helper alias for reading JSON files.

    This mirrors the naming used by earlier SDK code paths while delegating to
    `read_json_file` for actual behavior.
    """
    return read_json_file(path, label=label)


def load_schema(schema_path: str | Path | None = None) -> ValidationResult:
    """Load bundled or custom schema JSON object."""
    path = Path(schema_path) if schema_path is not None else default_schema_path()
    result = read_json_file(path, label="schema")

    if not result.ok:
        return result

    assert result.document is not None
    if result.document.get("$schema") is None:
        return ValidationResult(
            ok=False,
            errors=[f"Schema at {Path(path).resolve()} is missing '$schema'"],
        )

    return result


def _build_validator(schema_path: str | Path | None = None) -> tuple[Optional[Draft202012Validator], list[str]]:
    """Compile Draft 2020-12 validator from schema."""
    schema_result = load_schema(schema_path)
    if not schema_result.ok:
        return None, schema_result.errors

    assert schema_result.document is not None
    schema = schema_result.document

    try:
        Draft202012Validator.check_schema(schema)
    except Exception as exc:
        return None, [f"Schema is invalid: {exc}"]

    return Draft202012Validator(schema), []


def _format_validation_errors(errors: Iterable[Any]) -> list[str]:
    """Convert jsonschema error objects to stable strings."""
    formatted: list[str] = []

    for error in sorted(errors, key=lambda e: list(getattr(e, "path", []))):
        path_tokens = list(getattr(error, "path", []))
        if path_tokens:
            instance_path = "/" + "/".join(str(token) for token in path_tokens)
        else:
            instance_path = "/"

        message = getattr(error, "message", str(error))
        formatted.append(f"{instance_path} {message}".strip())

    return formatted


def validate_document(
    document: dict[str, Any],
    *,
    schema_path: str | Path | None = None,
) -> ValidationResult:
    """
    Validate a decoded ampersand declaration against schema.

    Returns:
      ValidationResult(ok=True, errors=[], document=<document>) on success
      ValidationResult(ok=False, errors=[...]) on failure
    """
    if not isinstance(document, dict):
        return ValidationResult(ok=False, errors=["Document must be a JSON object"])

    validator, validator_errors = _build_validator(schema_path)
    if validator is None:
        return ValidationResult(ok=False, errors=validator_errors)

    errors = _format_validation_errors(validator.iter_errors(document))
    if errors:
        return ValidationResult(ok=False, errors=errors)

    return ValidationResult(ok=True, errors=[], document=document)


def validate_file(
    file_path: str | Path,
    *,
    schema_path: str | Path | None = None,
) -> ValidationResult:
    """Load and validate a declaration file from disk."""
    loaded = read_json_file(file_path, label="ampersand declaration")
    if not loaded.ok:
        return loaded

    assert loaded.document is not None
    validated = validate_document(loaded.document, schema_path=schema_path)

    if not validated.ok:
        full_path = Path(file_path).expanduser().resolve()
        prefixed = [f"{full_path}: {message}" for message in validated.errors]
        return ValidationResult(ok=False, errors=prefixed)

    return validated
