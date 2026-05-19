"""
Shared fixtures for the ComplyEdge acceptance test suite.

Two tiers:
  - offline: no API key needed (corpus files, benchmark JSON, SDK source)
  - live:    requires COMPLYEDGE_API_KEY; skipped automatically when absent
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest
import requests

# ---------------------------------------------------------------------------
# Ensure acceptance tests import the LOCAL SDK source (sdks/python/) rather
# than whatever version may be installed system-wide.  Insert at position 0
# so the local copy always wins.
# ---------------------------------------------------------------------------
_SDK_SRC = str(Path(__file__).parent.parent.parent / "sdks" / "python")
if _SDK_SRC not in sys.path:
    sys.path.insert(0, _SDK_SRC)


@pytest.fixture(autouse=True)
def mock_openai_globally():
    """No-op: acceptance tests run against real files and the live API, not mocks."""
    yield

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).parent.parent.parent

RULES_REGO_DIR       = REPO_ROOT / "rules" / "rego" / "complyedge"
RULES_REGULATIONS_DIR = REPO_ROOT / "rules" / "regulations"
SDK_DIR              = REPO_ROOT / "sdks" / "python" / "complyedge"
BENCHMARK_RESULTS_DIR = REPO_ROOT / "scripts" / "benchmark" / "results"

# ---------------------------------------------------------------------------
# Live test fixtures
# ---------------------------------------------------------------------------

DEFAULT_API_BASE_URL = "https://api.complyedge.io"


@pytest.fixture(scope="session")
def api_key() -> str:
    """Return the API key; skip the test when the env var is absent."""
    key = os.getenv("COMPLYEDGE_API_KEY", "")
    if not key:
        pytest.skip("COMPLYEDGE_API_KEY not set — live tests skipped")
    return key


@pytest.fixture(scope="session")
def api_base_url() -> str:
    return os.getenv("COMPLYEDGE_API_URL", DEFAULT_API_BASE_URL)


@pytest.fixture(scope="session")
def live_session(api_key: str, api_base_url: str) -> requests.Session:
    """Reusable HTTP session pre-loaded with auth headers."""
    s = requests.Session()
    s.headers.update(
        {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
    )
    return s
