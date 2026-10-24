"""TrustLint CLI coverage (Click CliRunner; no network except mocked)."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import yaml
from click.testing import CliRunner
from trustlint.cli import cli, main


def _rules_dir(tmp_path: Path) -> Path:
    rules = tmp_path / "rules"
    rules.mkdir()
    (rules / "r.yaml").write_text(
        yaml.safe_dump(
            {
                "id": "test.cli",
                "title": "CLI rule",
                "jurisdiction": "EU",
                "severity": "high",
                "description": "hit",
                "category": "test",
                "source": {"citation": "Art 1"},
                "remediation": {"message": "fix it"},
                "conditions": [
                    {
                        "type": "regex",
                        "value": r"social\s+scoring",
                        "description": "phrase",
                        "flags": "i",
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    return rules


def test_check_text_json_and_threshold(tmp_path: Path):
    runner = CliRunner()
    rules = _rules_dir(tmp_path)
    clean = runner.invoke(
        cli,
        ["--rules-dir", str(rules), "check", "--text", "hello", "--json"],
    )
    assert clean.exit_code == 0
    payload = json.loads(clean.output)
    assert payload["violations"] == []

    hit = runner.invoke(
        cli,
        [
            "--rules-dir",
            str(rules),
            "check",
            "--text",
            "social scoring now",
            "--json",
            "--severity-threshold",
            "high",
        ],
    )
    assert hit.exit_code == 1
    assert json.loads(hit.output)["violations"][0]["rule_id"] == "test.cli"

    permissive = runner.invoke(
        cli,
        [
            "--rules-dir",
            str(rules),
            "check",
            "--text",
            "social scoring",
            "--severity-threshold",
            "critical",
        ],
    )
    assert permissive.exit_code == 0


def test_check_file_verbose_and_missing(tmp_path: Path):
    runner = CliRunner()
    rules = _rules_dir(tmp_path)
    f = tmp_path / "prompt.txt"
    f.write_text("social scoring", encoding="utf-8")
    ok = runner.invoke(
        cli,
        ["--rules-dir", str(rules), "check", str(f), "--verbose"],
    )
    assert ok.exit_code == 1
    assert "test.cli" in ok.output

    missing = runner.invoke(
        cli,
        ["--rules-dir", str(rules), "check", str(tmp_path / "nope.txt")],
    )
    assert missing.exit_code == 2


def test_check_no_rules(tmp_path: Path, monkeypatch):
    runner = CliRunner()
    # Isolate from repo rules/regulations discovery and any installed corpus.
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    empty = tmp_path / "empty"
    empty.mkdir()
    no_rules = runner.invoke(cli, ["--rules-dir", str(empty), "check", "--text", "x"])
    assert no_rules.exit_code == 2
    assert "No rules loaded" in no_rules.output


def test_rules_list(tmp_path: Path):
    runner = CliRunner()
    rules = _rules_dir(tmp_path)
    listed = runner.invoke(cli, ["--rules-dir", str(rules), "rules", "list", "-j", "EU"])
    assert listed.exit_code == 0
    assert "test.cli" in listed.output

    empty = tmp_path / "empty2"
    empty.mkdir()
    none = runner.invoke(cli, ["--rules-dir", str(empty), "rules", "list"])
    assert "No rules" in none.output


def test_scan_offline_fallback(tmp_path: Path, monkeypatch):
    runner = CliRunner()
    rules = _rules_dir(tmp_path)
    monkeypatch.delenv("COMPLYEDGE_API_KEY", raising=False)
    # scan builds its own engine without --rules-dir; it finds rules/regulations
    # in the current directory, so run from a dir that has one.
    repo = tmp_path / "repo"
    (repo / "rules" / "regulations").mkdir(parents=True)
    (repo / "rules" / "regulations" / "r.yaml").write_text(
        (rules / "r.yaml").read_text(encoding="utf-8"), encoding="utf-8"
    )
    monkeypatch.chdir(repo)
    result = runner.invoke(cli, ["scan", "--text", "social scoring"])
    assert result.exit_code == 1


def test_scan_api_pass_and_fail(tmp_path: Path):
    runner = CliRunner()

    class FakeResp:
        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def read(self):
            return json.dumps(
                {"allowed": True, "violations": [], "latency_ms": 12}
            ).encode()

    with patch("urllib.request.urlopen", return_value=FakeResp()):
        ok = runner.invoke(
            cli, ["scan", "--api-key", "k", "--text", "benign"]
        )
    assert ok.exit_code == 0
    assert "PASS" in ok.output

    class FakeBlock:
        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def read(self):
            return json.dumps(
                {
                    "allowed": False,
                    "violations": [
                        {
                            "severity": "high",
                            "rule_id": "x",
                            "rule_description": "bad",
                        }
                    ],
                    "latency_ms": 9,
                }
            ).encode()

    with patch("urllib.request.urlopen", return_value=FakeBlock()):
        blocked = runner.invoke(
            cli, ["scan", "--api-key", "k", "--text", "bad"]
        )
    assert blocked.exit_code == 1


def test_scan_api_unreachable():
    runner = CliRunner()
    from urllib.error import URLError

    with patch("urllib.request.urlopen", side_effect=URLError("down")):
        result = runner.invoke(
            cli, ["scan", "--api-key", "k", "--text", "x"]
        )
    assert result.exit_code == 2
    assert "Not falling back" in result.output


def test_rules_update_writes_nothing(tmp_path: Path, monkeypatch):
    runner = CliRunner()
    monkeypatch.setenv("HOME", str(tmp_path))
    stale = tmp_path / ".trustlint" / "rules"
    stale.mkdir(parents=True)
    with patch("urllib.request.urlopen") as urlopen:
        result = runner.invoke(cli, ["rules", "update"])
    assert result.exit_code == 0
    urlopen.assert_not_called()
    assert "pip install -U trustlint" in result.output
    assert "no longer read" in result.output
    assert list(stale.iterdir()) == []


def test_main_entrypoint():
    with patch("trustlint.cli.cli") as mocked:
        main()
        mocked.assert_called_once()
