"""Tests for complyedge CLI commands."""

import json
from unittest.mock import MagicMock, patch

from click.testing import CliRunner
from complyedge.cli import cli


class TestLogin:
    def test_login_saves_key(self, tmp_path):
        runner = CliRunner()
        config_file = tmp_path / "config.json"

        with patch("complyedge.cli.CONFIG_FILE", config_file), patch(
            "complyedge.cli.CONFIG_DIR", tmp_path
        ):
            result = runner.invoke(cli, ["login", "--api-key", "test-key-123"])

        assert result.exit_code == 0
        assert "Logged in" in result.output
        config = json.loads(config_file.read_text())
        assert config["api_key"] == "test-key-123"

    def test_login_saves_base_url(self, tmp_path):
        runner = CliRunner()
        config_file = tmp_path / "config.json"

        with patch("complyedge.cli.CONFIG_FILE", config_file), patch(
            "complyedge.cli.CONFIG_DIR", tmp_path
        ):
            runner.invoke(
                cli,
                ["login", "--api-key", "key", "--base-url", "http://localhost:8000"],
            )

        config = json.loads(config_file.read_text())
        assert config["base_url"] == "http://localhost:8000"


def _mock_ce(safe=True, violations=None):
    mock_result = MagicMock()
    mock_result.safe = safe
    mock_result.event_id = "evt-123"
    mock_result.violations = violations or []
    client = MagicMock()
    client.check.return_value = mock_result
    return client


class TestScan:
    def test_scan_no_api_key(self):
        runner = CliRunner()
        with patch("complyedge.cli._get_api_key", return_value=None):
            result = runner.invoke(cli, ["scan", "--text", "hello"])
        assert result.exit_code == 2
        assert "No API key" in result.output

    def test_scan_text_safe(self):
        runner = CliRunner()
        with patch("complyedge.cli._get_api_key", return_value="test-key"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=_mock_ce(True)):
            result = runner.invoke(cli, ["scan", "--text", "Process this invoice"])
        assert result.exit_code == 0
        assert "COMPLIANT" in result.output

    def test_scan_text_violation(self):
        runner = CliRunner()
        v = MagicMock()
        v.severity = "critical"
        v.rule_id = "SOX_001"
        v.rule_description = "Material disclosure"
        v.reason = "Review with legal"

        with patch("complyedge.cli._get_api_key", return_value="test-key"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=_mock_ce(False, [v])):
            result = runner.invoke(cli, ["scan", "--text", "Revenue will increase 25%"])
        assert result.exit_code == 1
        assert "SOX_001" in result.output

    def test_scan_file(self, tmp_path):
        runner = CliRunner()
        test_file = tmp_path / "prompt.txt"
        test_file.write_text("Test prompt")

        with patch("complyedge.cli._get_api_key", return_value="test-key"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=_mock_ce(True)):
            result = runner.invoke(cli, ["scan", str(test_file)])
        assert result.exit_code == 0

    def test_scan_stdin(self):
        runner = CliRunner()
        with patch("complyedge.cli._get_api_key", return_value="test-key"), patch(
            "complyedge.cli._load_config", return_value={}
        ), patch("complyedge.cli._create_client", return_value=_mock_ce(True)):
            result = runner.invoke(cli, ["scan"], input="Piped text")
        assert result.exit_code == 0

    def test_scan_missing_file(self):
        runner = CliRunner()
        with patch("complyedge.cli._get_api_key", return_value="test-key"):
            result = runner.invoke(cli, ["scan", "/tmp/nonexistent_xyz_cli.txt"])
        assert result.exit_code == 2


class TestStatus:
    @patch("complyedge.cli._get_api_key", return_value="ce_live_abc123xyz789")
    @patch("complyedge.cli._load_config", return_value={})
    def test_status_with_key(self, mock_config, mock_key):
        runner = CliRunner()
        result = runner.invoke(cli, ["status"])
        assert result.exit_code == 0
        assert "ComplyEdge" in result.output

    @patch("complyedge.cli._get_api_key", return_value=None)
    @patch("complyedge.cli._load_config", return_value={})
    def test_status_no_key(self, mock_config, mock_key):
        runner = CliRunner()
        result = runner.invoke(cli, ["status"])
        assert result.exit_code == 0
        assert "not configured" in result.output


class TestVersion:
    def test_version(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["--version"])
        assert result.exit_code == 0
        assert "complyedge" in result.output
