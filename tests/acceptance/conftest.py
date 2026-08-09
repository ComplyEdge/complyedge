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

RULES_REGO_DIR = REPO_ROOT / "rules" / "rego" / "complyedge"
RULES_REGULATIONS_DIR = REPO_ROOT / "rules" / "regulations"
SDK_DIR = REPO_ROOT / "sdks" / "python" / "complyedge"
BENCHMARK_RESULTS_DIR = REPO_ROOT / "scripts" / "benchmark" / "results"

# ---------------------------------------------------------------------------
# Live test fixtures
# ---------------------------------------------------------------------------

DEFAULT_API_BASE_URL = "https://api.complyedge.io"


#: Key prefixes that are only valid against a local or dev deployment. A key
#: like this must never be used to assert PRODUCTION behaviour.
NON_PRODUCTION_KEY_PREFIXES = ("ce_dev_", "ce_test_", "ce_local_", "demo")


@pytest.fixture(scope="session")
def api_key(api_base_url: str) -> str:
    """Return the API key; skip when it is absent or wrong for the target.

    Absence is not the only case that must skip. Anything that loads a .env
    file into os.environ before these tests run -- a sibling test module, a
    shell helper, a CI step -- can populate COMPLYEDGE_API_KEY with a local or
    development key while COMPLYEDGE_API_URL still points at production. The
    live tests then stop skipping and assert against production using a key it
    correctly rejects, producing a wall of 401s that look like product
    failures and are not.

    So the pairing is checked, not just presence. A dev key against production
    is a misconfiguration, and it skips with a message saying which of the two
    to change.
    """
    key = os.getenv("COMPLYEDGE_API_KEY", "")
    if not key:
        pytest.skip("COMPLYEDGE_API_KEY not set — live tests skipped")

    is_production_target = "api.complyedge.io" in api_base_url
    is_non_production_key = key.lower().startswith(NON_PRODUCTION_KEY_PREFIXES)
    if is_production_target and is_non_production_key:
        pytest.skip(
            f"COMPLYEDGE_API_KEY looks like a non-production key "
            f"({key[:7]}...) but COMPLYEDGE_API_URL targets production "
            f"({api_base_url}). Set a production key, or point "
            f"COMPLYEDGE_API_URL at your local/dev deployment."
        )
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
