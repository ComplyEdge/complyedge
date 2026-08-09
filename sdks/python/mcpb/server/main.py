"""MCPB stdio entrypoint for ComplyEdge TrustLint.

Prefer host launch via uvx (see manifest.json mcp_config). This module is a
fallback when the host runs entry_point with a Python that already has
``complyedge[mcp]==0.2.8`` installed.
"""
from __future__ import annotations


def main() -> None:
    from complyedge.mcp_server import main as _main

    _main()


if __name__ == "__main__":
    main()
