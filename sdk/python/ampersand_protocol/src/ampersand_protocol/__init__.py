"""Ampersand Protocol Python SDK."""

from .compose import compose_capabilities, normalize_capabilities
from .mcp import generate_mcp_config
from .validator import validate_document, validate_file

__all__ = [
    "validate_document",
    "validate_file",
    "normalize_capabilities",
    "compose_capabilities",
    "generate_mcp_config",
]

__version__ = "0.1.0"
