"""
Shared fixtures for the ComplyEdge acceptance test suite.

Offline only for the suite itself: corpus files, benchmark JSON, SDK source.
Region-aware test-tenant key helpers remain for unit tests that pin the
picker contract (a key only authenticates on its home stack).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

# Ensure acceptance tests import the LOCAL SDK source (sdks/python/) rather
# than whatever version may be installed system-wide.
_SDK_SRC = str(Path(__file__).parent.parent.parent / "sdks" / "python")
if _SDK_SRC not in sys.path:
    sys.path.insert(0, _SDK_SRC)


@pytest.fixture(autouse=True)
def mock_openai_globally():
    """No-op placeholder kept for suite shape; acceptance stays offline."""
    yield


REPO_ROOT = Path(__file__).parent.parent.parent

RULES_REGO_DIR = REPO_ROOT / "rules" / "rego" / "complyedge"
RULES_REGULATIONS_DIR = REPO_ROOT / "rules" / "regulations"
SDK_DIR = REPO_ROOT / "sdks" / "python" / "complyedge"
BENCHMARK_RESULTS_DIR = REPO_ROOT / "scripts" / "benchmark" / "results"

# ---------------------------------------------------------------------------
# Region-aware test-tenant key picker (unit-tested; not used by offline suite)
# ---------------------------------------------------------------------------

DEFAULT_API_BASE_URL = "https://eu.api.complyedge.io"

#: Fallback live identity when COMPLYEDGE_API_KEY is unset: a dedicated test
#: tenant's key for the TARGET region, ~/.complyedge/test-tenant/
#: <name>.<region>.key (mode 0600).
TEST_TENANT_KEY_DIR = Path.home() / ".complyedge" / "test-tenant"


def _target_region(api_base_url: str) -> str:
    return "eu-central-1" if "eu.api." in api_base_url else "us-west-2"


def _test_tenant_key(api_base_url: str = DEFAULT_API_BASE_URL) -> str:
    try:
        files = sorted(
            TEST_TENANT_KEY_DIR.glob(f"*.{_target_region(api_base_url)}.key")
        )
        return files[0].read_text().strip() if files else ""
    except OSError:
        return ""
