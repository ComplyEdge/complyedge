"""
Extended offline unit tests for complyedge.cli.

Covers commands and helpers not exercised by test_complyedge_cli.py:
signup, pre-deploy (all risk tiers/branches), rules, status health checks,
config helpers, _create_client and _mask_key. All network/API access is
mocked; nothing hits a live server.
"""

import json
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from click.testing import CliRunner
from complyedge import cli as cli_mod
from complyedge.cli import (
    _create_client,
    _get_api_key,
    _load_config,
    _mask_key,
    cli,
    main,
)


class TestConfigHelpers:
    def test_load_config_reads_existing_file(self, tmp_path):
        cfgfile = tmp_path / "config.json"
        cfgfile.write_text(json.dumps({"api_key": "abc", "base_url": "http://x"}))
        with patch.object(cli_mod, "CONFIG_FILE", cfgfile):
            cfg = _load_config()
        assert cfg["api_key"] == "abc"
        assert cfg["base_url"] == "http://x"

    def test_load_config_missing_returns_empty(self, tmp_path):
        with patch.object(cli_mod, "CONFIG_FILE", tmp_path / "nope.json"):
            assert _load_config() == {}

    def test_get_api_key_prefers_env(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "env-key")
        assert _get_api_key() == "env-key"

    def test_get_api_key_falls_back_to_config(self, monkeypatch):
        monkeypatch.delenv("COMPLYEDGE_API_KEY", raising=False)
        with patch.object(cli_mod, "_load_config", return_value={"api_key": "cfg-key"}):
            assert _get_api_key() == "cfg-key"

    def test_get_api_key_none_when_unset(self, monkeypatch):
        monkeypatch.delenv("COMPLYEDGE_API_KEY", raising=False)
        with patch.object(cli_mod, "_load_config", return_value={}):
            assert _get_api_key() is None


class TestMaskKey:
    def test_short_key_fully_masked(self):
        assert _mask_key("12345678") == "***"

    def test_long_key_partial(self):
        assert _mask_key("ce_live_abcdef1234") == "ce_liv...1234"


class TestCreateClient:
    def test_create_client_with_base_url(self):
        fake_ce = MagicMock()
        with patch("complyedge.ComplyEdge", fake_ce):
            _create_client("k", "http://host")
        fake_ce.assert_called_once_with(api_key="k", base_url="http://host")

    def test_create_client_without_base_url(self):
        fake_ce = MagicMock()
        with patch("complyedge.ComplyEdge", fake_ce):
            _create_client("k")
        fake_ce.assert_called_once_with(api_key="k")


class TestSignup:
    def test_signup_opens_browser(self):
        runner = CliRunner()
        with patch("complyedge.cli.webbrowser.open") as mock_open:
            result = runner.invoke(cli, ["signup"])
        assert result.exit_code == 0
        assert "dashboard.complyedge.io" in result.output
        mock_open.assert_called_once_with("https://dashboard.complyedge.io/?intent=get-started")


class TestScanExtra:
    def test_scan_no_input_when_tty(self):
        # With no --text/file/pipe and stdin being a TTY, scan errors out.
        # CliRunner swaps the real sys.stdin, so we replace the cli module's
        # `sys` reference with a proxy that forces isatty()->True while keeping
        # the real sys.exit so Click can capture the exit code.
        import sys as real_sys

        runner = CliRunner()
        fake_sys = MagicMock(wraps=real_sys)
        fake_sys.stdin.isatty.return_value = True
        fake_sys.exit = real_sys.exit
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli.sys", fake_sys
        ):
            result = runner.invoke(cli, ["scan"])
        assert result.exit_code == 2
        assert "Provide --text" in result.output

    def test_scan_api_error(self):
        runner = CliRunner()
        client = MagicMock()
        client.check.side_effect = RuntimeError("boom")
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=client):
            result = runner.invoke(cli, ["scan", "--text", "hello"])
        assert result.exit_code == 2
        assert "API error" in result.output

    def test_scan_verbose_shows_reason(self):
        runner = CliRunner()
        v = SimpleNamespace(
            severity="high",
            rule_id="SOX_001",
            rule_description="Material disclosure",
            reason="Consult legal before publishing",
        )
        result_obj = SimpleNamespace(safe=False, event_id="evt-1", violations=[v])
        client = MagicMock()
        client.check.return_value = result_obj
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=client):
            result = runner.invoke(cli, ["scan", "--text", "risky", "--verbose"])
        assert result.exit_code == 1
        assert "Consult legal before publishing" in result.output
        assert "SOX_001" in result.output


class TestStatusHealth:
    def _run(self, status_code=None, raise_exc=False):
        runner = CliRunner()
        resp = MagicMock()
        resp.status_code = status_code
        get = MagicMock(return_value=resp)
        if raise_exc:
            get.side_effect = RuntimeError("no route")
        with patch(
            "complyedge.cli._get_api_key", return_value="ce_live_abc123xyz"
        ), patch("complyedge.cli._load_config", return_value={}), patch(
            "httpx.get", get
        ):
            return runner.invoke(cli, ["status"])

    def test_status_healthy(self):
        result = self._run(status_code=200)
        assert result.exit_code == 0
        assert "healthy" in result.output

    def test_status_degraded(self):
        result = self._run(status_code=503)
        assert "degraded" in result.output

    def test_status_unreachable(self):
        result = self._run(raise_exc=True)
        assert "unreachable" in result.output


class TestRulesInfo:
    def test_rules_no_api_key(self):
        runner = CliRunner()
        with patch("complyedge.cli._get_api_key", return_value=None):
            result = runner.invoke(cli, ["rules"])
        assert result.exit_code == 2
        assert "No API key" in result.output

    def test_rules_success(self):
        runner = CliRunner()
        resp = MagicMock()
        resp.status_code = 200
        resp.json.return_value = {
            "bundle_id": "eu-ai-act-2025",
            "version": "1.4.0",
            "rule_count": 12,
            "jurisdictions": ["EU", "US"],
            "generated_at": "2026-01-01",
        }
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("httpx.get", return_value=resp):
            result = runner.invoke(cli, ["rules"])
        assert result.exit_code == 0
        assert "eu-ai-act-2025" in result.output
        assert "1.4.0" in result.output
        assert "EU, US" in result.output

    def test_rules_api_error_status(self):
        runner = CliRunner()
        resp = MagicMock()
        resp.status_code = 500
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("httpx.get", return_value=resp):
            result = runner.invoke(cli, ["rules"])
        assert result.exit_code == 2
        assert "API error: 500" in result.output

    def test_rules_request_exception(self):
        runner = CliRunner()
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("httpx.get", side_effect=RuntimeError("dns fail")):
            result = runner.invoke(cli, ["rules"])
        assert result.exit_code == 2
        assert "Error:" in result.output


def _predeploy_client(result_dict):
    client = MagicMock()
    client.assess_pre_deployment.return_value = result_dict
    return client


class TestPreDeploy:
    def test_no_api_key(self, tmp_path, monkeypatch):
        # The --api-key option also reads COMPLYEDGE_API_KEY via envvar, so clear
        # it (a leaked env var would otherwise bypass the no-key branch).
        monkeypatch.delenv("COMPLYEDGE_API_KEY", raising=False)
        runner = CliRunner()
        f = tmp_path / "c.json"
        f.write_text(json.dumps({"system_prompt": "x"}))
        with patch("complyedge.cli._get_api_key", return_value=None):
            result = runner.invoke(
                cli, ["pre-deploy", "-f", str(f)], env={"COMPLYEDGE_API_KEY": ""}
            )
        assert result.exit_code == 2
        assert "No API key" in result.output

    def test_file_not_found(self):
        runner = CliRunner()
        with patch("complyedge.cli._get_api_key", return_value="k"):
            result = runner.invoke(
                cli, ["pre-deploy", "-f", "/tmp/does_not_exist_zzz.json"]
            )
        assert result.exit_code == 2
        assert "File not found" in result.output

    def test_parse_error(self, tmp_path):
        runner = CliRunner()
        f = tmp_path / "bad.json"
        f.write_text("{not valid json")
        with patch("complyedge.cli._get_api_key", return_value="k"):
            result = runner.invoke(cli, ["pre-deploy", "-f", str(f)])
        assert result.exit_code == 2
        assert "Failed to parse" in result.output

    def test_missing_system_prompt(self, tmp_path):
        runner = CliRunner()
        f = tmp_path / "c.json"
        f.write_text(json.dumps({"model_config": {}}))
        with patch("complyedge.cli._get_api_key", return_value="k"):
            result = runner.invoke(cli, ["pre-deploy", "-f", str(f)])
        assert result.exit_code == 2
        assert "system_prompt" in result.output

    def test_api_error(self, tmp_path):
        runner = CliRunner()
        f = tmp_path / "c.json"
        f.write_text(json.dumps({"system_prompt": "hello"}))
        client = MagicMock()
        client.assess_pre_deployment.side_effect = RuntimeError("upstream")
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=client):
            result = runner.invoke(cli, ["pre-deploy", "-f", str(f)])
        assert result.exit_code == 2
        assert "API error" in result.output

    def test_pass_minimal_tier(self, tmp_path):
        runner = CliRunner()
        f = tmp_path / "c.json"
        f.write_text(json.dumps({"system_prompt": "friendly assistant"}))
        client = _predeploy_client(
            {
                "risk_tier": "minimal",
                "compliance_score": 1.0,
                "violations": [],
                "required_disclosures": [],
                "eu_ai_act_category": "minimal-risk",
                "estimated_deadline": "",
            }
        )
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=client):
            result = runner.invoke(cli, ["pre-deploy", "-f", str(f)])
        assert result.exit_code == 0
        assert "PASS" in result.output

    def test_unacceptable_tier_blocked(self, tmp_path):
        runner = CliRunner()
        f = tmp_path / "c.json"
        f.write_text(json.dumps({"system_prompt": "social scoring engine"}))
        client = _predeploy_client(
            {
                "risk_tier": "unacceptable",
                "compliance_score": 0.0,
                "violations": [
                    {
                        "article": "Art. 5",
                        "rule_id": "PROHIBITED_001",
                        "description": "Social scoring is prohibited",
                        "required_action": "Remove feature",
                    }
                ],
                "required_disclosures": [],
                "eu_ai_act_category": "prohibited",
                "estimated_deadline": "2025-02-02",
            }
        )
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=client):
            result = runner.invoke(cli, ["pre-deploy", "-f", str(f), "--verbose"])
        assert result.exit_code == 1
        assert "BLOCKED" in result.output
        assert "PROHIBITED_001" in result.output
        assert "Remove feature" in result.output

    def test_high_tier_with_violations(self, tmp_path):
        runner = CliRunner()
        f = tmp_path / "c.json"
        f.write_text(json.dumps({"system_prompt": "hiring decision system"}))
        client = _predeploy_client(
            {
                "risk_tier": "high",
                "compliance_score": 0.6,
                "violations": [
                    {
                        "article": "Art. 6",
                        "rule_id": "HIGH_001",
                        "description": "Conformity assessment required",
                    }
                ],
                "required_disclosures": ["Human oversight required"],
                "eu_ai_act_category": "employment-workers",
                "estimated_deadline": "2027-12-02",
            }
        )
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=client):
            result = runner.invoke(cli, ["pre-deploy", "-f", str(f)])
        assert result.exit_code == 1
        assert "HIGH RISK" in result.output
        assert "Human oversight required" in result.output

    def test_high_tier_no_violations_passes(self, tmp_path):
        runner = CliRunner()
        f = tmp_path / "c.json"
        f.write_text(json.dumps({"system_prompt": "system"}))
        client = _predeploy_client(
            {
                "risk_tier": "high",
                "compliance_score": 0.9,
                "violations": [],
                "required_disclosures": [],
                "eu_ai_act_category": "essential-services",
                "estimated_deadline": "2027-12-02",
            }
        )
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=client):
            result = runner.invoke(cli, ["pre-deploy", "-f", str(f)])
        assert result.exit_code == 0
        assert "HIGH RISK" in result.output

    def test_limited_tier_with_violations_exit1(self, tmp_path):
        runner = CliRunner()
        f = tmp_path / "c.json"
        f.write_text(json.dumps({"system_prompt": "chatbot"}))
        client = _predeploy_client(
            {
                "risk_tier": "limited",
                "compliance_score": 0.8,
                "violations": [
                    {
                        "article": "Art. 52",
                        "rule_id": "TRANS_001",
                        "description": "Must disclose AI",
                    }
                ],
                "required_disclosures": ["Disclose AI interaction"],
                "eu_ai_act_category": "limited-risk",
                "estimated_deadline": "",
            }
        )
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=client):
            result = runner.invoke(cli, ["pre-deploy", "-f", str(f)])
        assert result.exit_code == 1
        assert "Issues found" in result.output

    def test_yaml_config_file(self, tmp_path):
        runner = CliRunner()
        f = tmp_path / "c.yaml"
        f.write_text("system_prompt: friendly assistant\n")
        client = _predeploy_client(
            {
                "risk_tier": "minimal",
                "compliance_score": 1.0,
                "violations": [],
                "required_disclosures": [],
                "eu_ai_act_category": "minimal-risk",
                "estimated_deadline": "",
            }
        )
        with patch("complyedge.cli._get_api_key", return_value="k"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=client):
            result = runner.invoke(cli, ["pre-deploy", "-f", str(f)])
        assert result.exit_code == 0
        # system_prompt was read from YAML and forwarded to the client.
        client.assess_pre_deployment.assert_called_once()
        assert (
            client.assess_pre_deployment.call_args.kwargs["system_prompt"]
            == "friendly assistant"
        )


class TestMain:
    def test_main_invokes_cli(self):
        # main() just calls cli(); invoking with no args exits cleanly via Click.
        with patch.object(cli_mod, "cli") as mock_cli:
            main()
        mock_cli.assert_called_once()
