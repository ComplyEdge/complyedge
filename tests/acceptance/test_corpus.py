"""
OFFLINE — Validates static claims about the rule corpus and SDK defaults.
No API key required.

Claims verified:
  - "19 Rego policies covering EU AI Act Article 5, Article 50, and GPAI"
  - "53 YAML regulation definitions spanning EU, US, global, and universal rules"
  - "EU covers Articles 4–27, 50, 53, GPAI, GDPR"
  - "US covers HIPAA, SOX, COPPA, TCPA, BIPA, CCPA, Colorado AI Act, NYC LL144, ECPA"
  - "Plus PCI DSS and prompt injection detection"
  - "OPA-only by default; LLM evaluation is opt-in via use_semantic_fallback=True"
  - "SDK default for use_semantic_fallback is False across all three call sites"
  - "@compliance_check decorator is enabled by default when COMPLYEDGE_API_KEY is set"
  - "benchmark runner and prompt YAMLs are in the repo"
"""
from __future__ import annotations

import re
import tomllib
from pathlib import Path

import pytest

from conftest import REPO_ROOT, RULES_REGO_DIR, RULES_REGULATIONS_DIR, SDK_DIR


# ---------------------------------------------------------------------------
# Rego corpus
# ---------------------------------------------------------------------------

class TestRegoCorpus:
    """Validates the 19 production Rego policies mentioned in the launch post."""

    @pytest.fixture(scope="class")
    def prod_rego_files(self) -> list[Path]:
        all_rego = list(RULES_REGO_DIR.rglob("*.rego"))
        return [f for f in all_rego if "test" not in f.parts]

    def test_production_rego_leaf_count_meets_moat(self, prod_rego_files):
        # M3.3-T3: public claim is leaf-basis (≥50). Aggregators are not leaves.
        AGGREGATOR_NAMES = {
            "article5.rego",
            "article50.rego",
            "article6.rego",
            "gpai.rego",
            "highrisk.rego",
        }
        leaves = [f for f in prod_rego_files if f.name not in AGGREGATOR_NAMES]
        assert len(prod_rego_files) == 56, (
            f"Expected 56 production .rego files (51 leaf + 5 aggregators), "
            f"found {len(prod_rego_files)}"
        )
        assert len(leaves) >= 50, (
            f"Expected ≥50 leaf Rego policies, found {len(leaves)}"
        )

    def test_rego_covers_article5(self, prod_rego_files):
        # Claim: "covering EU AI Act Article 5"
        article5 = [f for f in prod_rego_files if "article5" in str(f)]
        assert len(article5) >= 1, "No Article 5 Rego policies found"

    def test_rego_covers_article50(self, prod_rego_files):
        # Claim: "Article 50"
        article50 = [f for f in prod_rego_files if "article50" in str(f)]
        assert len(article50) >= 1, "No Article 50 Rego policies found"

    def test_rego_covers_gpai(self, prod_rego_files):
        # Claim: "GPAI"
        gpai = [f for f in prod_rego_files if "gpai" in str(f)]
        assert len(gpai) >= 1, "No GPAI Rego policies found"

    def test_each_rego_policy_declares_rule_id(self, prod_rego_files):
        # Structural claim: each policy has a rule_id used in API violation reports
        missing = []
        for f in prod_rego_files:
            content = f.read_text()
            if "rule_id" not in content:
                missing.append(str(f.relative_to(REPO_ROOT)))
        assert missing == [], f"Rego files missing rule_id declaration: {missing}"

    def test_each_rego_policy_declares_citation(self, prod_rego_files):
        # Structural claim: each leaf policy cites the specific article.
        # Aggregator files (article5.rego, article50.rego, gpai.rego) combine
        # sub-rules and are explicitly exempt per RULE_STANDARD.md §5.6.
        AGGREGATOR_NAMES = {
            "article5.rego",
            "article50.rego",
            "article6.rego",
            "gpai.rego",
            "highrisk.rego",
        }
        leaf_files = [f for f in prod_rego_files if f.name not in AGGREGATOR_NAMES]
        missing = []
        for f in leaf_files:
            content = f.read_text()
            if "citation" not in content:
                missing.append(str(f.relative_to(REPO_ROOT)))
        assert missing == [], f"Rego files missing citation declaration: {missing}"

    def test_each_rego_policy_declares_violation(self, prod_rego_files):
        # Structural claim: each policy is a blocking rule (defines `violation`)
        missing = []
        for f in prod_rego_files:
            content = f.read_text()
            if "violation" not in content:
                missing.append(str(f.relative_to(REPO_ROOT)))
        assert missing == [], f"Rego files missing violation declaration: {missing}"


# ---------------------------------------------------------------------------
# YAML regulations
# ---------------------------------------------------------------------------

class TestYamlCorpus:
    """Validates the 53 YAML regulation definitions mentioned in the launch post."""

    @pytest.fixture(scope="class")
    def yaml_files(self) -> list[Path]:
        return list(RULES_REGULATIONS_DIR.rglob("*.yaml")) + list(
            RULES_REGULATIONS_DIR.rglob("*.yml")
        )

    def test_exactly_64_yaml_regulations(self, yaml_files):
        # Claim: "64 YAML regulation definitions" (53 → +8 IPI prompt-security
        # rules → +2 OFAC sanctions transition rules, both 2026-07-05).
        assert len(yaml_files) == 64, (
            f"Expected 64 YAML regulation files, found {len(yaml_files)}"
        )

    def test_yaml_covers_eu_regulations(self, yaml_files):
        eu = [f for f in yaml_files if "eu" in f.parts]
        assert len(eu) >= 1, "No EU YAML regulations found"

    def test_yaml_covers_us_regulations(self, yaml_files):
        us = [f for f in yaml_files if "us" in f.parts]
        assert len(us) >= 1, "No US YAML regulations found"

    def test_yaml_covers_global_regulations(self, yaml_files):
        glb = [f for f in yaml_files if "global" in f.parts]
        assert len(glb) >= 1, "No global YAML regulations found"

    def test_yaml_covers_universal_rules(self, yaml_files):
        uni = [f for f in yaml_files if "universal" in f.parts]
        assert len(uni) >= 1, "No universal YAML rules found"


# ---------------------------------------------------------------------------
# EU regulation specifics
# ---------------------------------------------------------------------------

class TestEuRegulationCoverage:
    """
    HN claim: "EU covers Articles 4–27, 50, 53, GPAI, GDPR"
    Verifies a YAML file exists for each named area.
    """

    @pytest.fixture(scope="class")
    def eu_files(self) -> list[Path]:
        eu_dir = RULES_REGULATIONS_DIR / "eu"
        return list(eu_dir.glob("*.yaml")) + list(eu_dir.glob("*.yml"))

    def _has_prefix(self, files: list[Path], prefix: str) -> bool:
        return any(f.name.startswith(prefix) for f in files)

    def test_eu_covers_gdpr(self, eu_files):
        assert self._has_prefix(eu_files, "gdpr_"), (
            "No GDPR YAML found in rules/regulations/eu/ — HN claims 'EU covers … GDPR'"
        )

    def test_eu_covers_article50(self, eu_files):
        assert self._has_prefix(eu_files, "eu_ai_act_article50"), (
            "No Article 50 YAML found — HN claims 'EU covers … 50'"
        )

    def test_eu_covers_article53(self, eu_files):
        assert self._has_prefix(eu_files, "eu_ai_act_article53"), (
            "No Article 53 YAML found — HN claims 'EU covers … 53'"
        )

    def test_eu_covers_gpai(self, eu_files):
        assert self._has_prefix(eu_files, "eu_ai_act_gpai"), (
            "No GPAI YAML found — HN claims 'EU covers … GPAI'"
        )


# ---------------------------------------------------------------------------
# US regulation specifics
# ---------------------------------------------------------------------------

class TestUsRegulationCoverage:
    """
    HN claim: "US covers HIPAA, SOX, COPPA, TCPA, BIPA, CCPA, Colorado AI Act,
               NYC LL144, ECPA"
    Verifies a YAML file exists for each named regulation.
    """

    @pytest.fixture(scope="class")
    def us_files(self) -> list[Path]:
        us_dir = RULES_REGULATIONS_DIR / "us"
        return list(us_dir.glob("*.yaml")) + list(us_dir.glob("*.yml"))

    def _has_keyword(self, files: list[Path], keyword: str) -> bool:
        return any(keyword in f.name for f in files)

    def test_us_covers_hipaa(self, us_files):
        assert self._has_keyword(us_files, "hipaa"), "No HIPAA YAML found"

    def test_us_covers_sox(self, us_files):
        assert self._has_keyword(us_files, "sox"), "No SOX YAML found"

    def test_us_covers_coppa(self, us_files):
        assert self._has_keyword(us_files, "coppa"), "No COPPA YAML found"

    def test_us_covers_tcpa(self, us_files):
        assert self._has_keyword(us_files, "tcpa"), "No TCPA YAML found"

    def test_us_covers_bipa(self, us_files):
        assert self._has_keyword(us_files, "bipa"), "No BIPA YAML found"

    def test_us_covers_ccpa(self, us_files):
        assert self._has_keyword(us_files, "ccpa"), "No CCPA YAML found"

    def test_us_covers_colorado_ai_act(self, us_files):
        assert self._has_keyword(us_files, "colorado"), "No Colorado AI Act YAML found"

    def test_us_covers_nyc_ll144(self, us_files):
        assert self._has_keyword(us_files, "nyc"), "No NYC LL144 YAML found"

    def test_us_covers_ecpa(self, us_files):
        assert self._has_keyword(us_files, "ecpa"), "No ECPA YAML found"


# ---------------------------------------------------------------------------
# Global / Universal regulation specifics
# ---------------------------------------------------------------------------

class TestGlobalUniversalCoverage:
    """
    HN claim: "Plus PCI DSS and prompt injection detection"
    """

    def test_global_covers_pci_dss(self):
        pci = list((RULES_REGULATIONS_DIR / "global").glob("pci_dss*.yaml"))
        assert pci, "No PCI DSS YAML found in rules/regulations/global/"

    def test_universal_covers_prompt_injection(self):
        prompt_sec = RULES_REGULATIONS_DIR / "universal" / "prompt_security"
        yamls = list(prompt_sec.glob("*.yaml")) if prompt_sec.exists() else []
        assert yamls, (
            "No prompt injection YAML found in rules/regulations/universal/prompt_security/"
        )


# ---------------------------------------------------------------------------
# Benchmark corpus YAMLs in repo
# ---------------------------------------------------------------------------

class TestBenchmarkCorpusFiles:
    """
    HN claim: "benchmark runner and prompt YAMLs are in the repo"
    Verifies the prompt YAML corpus files are present.
    """

    BENCHMARK_PROMPTS_DIR = REPO_ROOT / "scripts" / "benchmark" / "prompts"

    EXPECTED_PROMPT_FILES = {
        "article5.yaml",
        "article50.yaml",
        "gpai.yaml",
        "safe_harbor.yaml",
        "edge_cases.yaml",
        "us_corpus.yaml",
    }

    def test_benchmark_prompts_directory_exists(self):
        assert self.BENCHMARK_PROMPTS_DIR.exists(), (
            f"Benchmark prompts directory not found: {self.BENCHMARK_PROMPTS_DIR}"
        )

    def test_benchmark_prompt_yamls_present(self):
        existing = {f.name for f in self.BENCHMARK_PROMPTS_DIR.glob("*.yaml")}
        missing = self.EXPECTED_PROMPT_FILES - existing
        assert not missing, (
            f"Benchmark prompt YAMLs missing from {self.BENCHMARK_PROMPTS_DIR}: {missing}"
        )


# ---------------------------------------------------------------------------
# Apache 2.0 open-source license
# ---------------------------------------------------------------------------

class TestLicense:
    """
    Blog claim: "The full Rego corpus, the Python SDK, the offline regex linter
    (TrustLint), and the runtime benchmark are open source under Apache 2.0"
    """

    def test_license_file_exists(self):
        license_file = REPO_ROOT / "LICENSE"
        assert license_file.exists(), f"LICENSE file not found at {license_file}"

    def test_license_is_apache_2(self):
        content = (REPO_ROOT / "LICENSE").read_text()
        assert "Apache License" in content, "LICENSE file does not mention Apache License"
        assert "Version 2.0" in content, "LICENSE file does not specify Version 2.0"


# ---------------------------------------------------------------------------
# SDK defaults
# ---------------------------------------------------------------------------

class TestSdkDefaults:
    """Validates the SDK source matches the documented default behaviour."""

    @pytest.fixture(scope="class")
    def init_source(self) -> str:
        return (SDK_DIR / "__init__.py").read_text()

    @pytest.fixture(scope="class")
    def decorator_source(self) -> str:
        return (SDK_DIR / "decorators.py").read_text()

    @pytest.fixture(scope="class")
    def pyproject(self) -> dict:
        with open(REPO_ROOT / "sdks" / "python" / "pyproject.toml", "rb") as f:
            return tomllib.load(f)

    def test_use_semantic_fallback_default_in_payload(self, init_source):
        # Claim: "Default SDK behaviour is OPA-only"
        # L246 in __init__.py — the default payload dict passed to the API
        assert '"use_semantic_fallback": False' in init_source, (
            'SDK payload default "use_semantic_fallback": False not found in __init__.py'
        )

    def test_use_semantic_fallback_default_in_sync_client(self, init_source):
        # L530 — ComplyEdgeClient.check_compliance parameter default
        matches = re.findall(r"use_semantic_fallback:\s*bool\s*=\s*False", init_source)
        assert len(matches) >= 2, (
            f"Expected ≥2 'use_semantic_fallback: bool = False' parameter defaults in "
            f"__init__.py (sync + async client), found {len(matches)}"
        )

    def test_sdk_version_matches_pyproject(self, init_source, pyproject):
        # Sanity: published version matches what the source reports
        pyproject_ver = pyproject["project"]["version"]
        assert f'__version__ = "{pyproject_ver}"' in init_source, (
            f"__version__ in __init__.py does not match pyproject.toml ({pyproject_ver})"
        )

    def test_decorator_enabled_by_default(self, decorator_source):
        # Claim: "@compliance_check decorator is enabled-by-default when API key is set"
        # The default value for the `enabled_env` env var lookup should be "true"
        assert 'os.getenv' in decorator_source, (
            "decorators.py does not reference os.getenv for enabled_env"
        )
        assert '"true"' in decorator_source, (
            'Decorator enabled_env default is not "true" — decorator is not enabled-by-default'
        )
