"""TrustLint CLI — offline compliance linter for AI agents."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Optional

import click

from trustlint import __version__
from trustlint.engine import TrustLintEngine, LintResult, Violation


# ANSI colors
RED = "\033[91m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
CYAN = "\033[96m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

SEVERITY_COLORS = {
    "critical": RED,
    "high": RED,
    "medium": YELLOW,
    "low": DIM,
}

# Ordering used by --severity-threshold (card 225): a threshold of `T`
# means exit 1 when any violation has severity at-or-above `T`. Default
# is `high` because that matches today's `LintResult.has_critical` semantics
# (which fires on critical OR high). Lowering to `medium` or `low` makes
# the gate stricter; raising to `critical` makes it permissive of `high`s.
SEVERITY_ORDER = {"critical": 3, "high": 2, "medium": 1, "low": 0}


def _meets_threshold(severity: str, threshold: str) -> bool:
    """Return True if `severity` is at-or-above `threshold`.

    Unknown severities are treated as below all thresholds (don't trigger
    exit 1) so a malformed rule can never escalate the gate by accident.
    """
    s = SEVERITY_ORDER.get(severity)
    t = SEVERITY_ORDER.get(threshold)
    if s is None or t is None:
        return False
    return s >= t


def _violation_to_dict(v: Violation) -> dict:
    return {
        "rule_id": v.rule_id,
        "title": v.title,
        "severity": v.severity,
        "jurisdiction": v.jurisdiction,
        "description": v.description,
        "citation": v.citation,
        "pattern_matched": v.pattern_matched,
        "remediation": v.remediation,
    }


def _emit_json(result: LintResult, file_path: Optional[str]) -> None:
    """Emit machine-parseable JSON for `trustlint check --json` (card 225)."""
    summary = {sev: 0 for sev in ("critical", "high", "medium", "low")}
    for v in result.violations:
        if v.severity in summary:
            summary[v.severity] += 1
    payload = {
        "file": file_path,
        "rules_evaluated": result.rules_evaluated,
        "violations": [_violation_to_dict(v) for v in result.violations],
        "summary": summary,
    }
    click.echo(json.dumps(payload))


def _print_result(result: LintResult, verbose: bool = False) -> None:
    if result.clean:
        click.echo(f"\n{GREEN}{BOLD}✅ No violations found{RESET} ({result.rules_evaluated} rules evaluated)")
        return

    click.echo(f"\n{BOLD}TrustLint Report{RESET}")
    click.echo(f"{'─' * 60}")

    for i, v in enumerate(result.violations, 1):
        color = SEVERITY_COLORS.get(v.severity, "")
        click.echo(f"\n{color}{BOLD}[{v.severity.upper()}]{RESET} {BOLD}{v.rule_id}{RESET}")
        click.echo(f"  {v.title}")
        click.echo(f"  {DIM}Jurisdiction: {v.jurisdiction} | Matched: {v.pattern_matched}{RESET}")
        if verbose and v.citation:
            click.echo(f"  {DIM}Citation: {v.citation[:120]}{'…' if len(v.citation) > 120 else ''}{RESET}")
        if verbose and v.remediation:
            click.echo(f"  {CYAN}Remediation: {v.remediation[:120]}{'…' if len(v.remediation) > 120 else ''}{RESET}")

    critical_count = sum(1 for v in result.violations if v.severity in ("critical", "high"))
    warn_count = sum(1 for v in result.violations if v.severity in ("medium", "low"))

    click.echo(f"\n{'─' * 60}")
    click.echo(
        f"{RED}{BOLD}{critical_count} critical/high{RESET}, "
        f"{YELLOW}{warn_count} medium/low{RESET} "
        f"({result.rules_evaluated} rules evaluated)"
    )


@click.group()
@click.version_option(version=__version__, prog_name="trustlint")
@click.option("--rules-dir", type=click.Path(exists=True), default=None, help="Path to rules directory")
@click.pass_context
def cli(ctx: click.Context, rules_dir: Optional[str]) -> None:
    """TrustLint — offline compliance linter for AI agents.

    Scans text against the ComplyEdge YAML rule corpus using Tier 1
    regex patterns. No API key required.
    """
    ctx.ensure_object(dict)
    ctx.obj["rules_dir"] = rules_dir


@cli.command()
@click.argument("target", required=False)
@click.option("--text", "-t", help="Text string to check (instead of a file)")
@click.option("--jurisdiction", "-j", help="Filter rules by jurisdiction (EU, US, GLOBAL)")
@click.option("--verbose", "-v", is_flag=True, help="Show citations and remediation")
@click.option(
    "--json",
    "json_output",
    is_flag=True,
    help="Emit machine-parseable JSON instead of the human-readable report (card 225).",
)
@click.option(
    "--severity-threshold",
    type=click.Choice(["critical", "high", "medium", "low"], case_sensitive=False),
    default="high",
    show_default=True,
    help=(
        "Minimum severity that causes the command to exit 1. Below this, "
        "violations are still reported but the exit code stays 0. Default "
        "'high' preserves the prior behaviour (LintResult.has_critical "
        "fires on critical OR high). Card 225."
    ),
)
@click.pass_context
def check(
    ctx: click.Context,
    target: Optional[str],
    text: Optional[str],
    jurisdiction: Optional[str],
    verbose: bool,
    json_output: bool,
    severity_threshold: str,
) -> None:
    """Check text or file for compliance violations.

    Examples:

      trustlint check --text "We expect revenue to increase by 25%"

      trustlint check prompt.txt

      trustlint check --text "social credit score" --jurisdiction EU

      trustlint check prompt.txt --json --severity-threshold critical
    """
    engine = TrustLintEngine(rules_dir=ctx.obj.get("rules_dir"))

    if not engine.rules:
        click.echo(f"{YELLOW}⚠ No rules loaded. Run 'trustlint init' or use --rules-dir{RESET}", err=True)
        sys.exit(2)

    if text:
        input_text = text
    elif target:
        path = Path(target)
        if not path.exists():
            click.echo(f"{RED}Error: file not found: {target}{RESET}", err=True)
            sys.exit(2)
        input_text = path.read_text(encoding="utf-8")
    elif not sys.stdin.isatty():
        input_text = sys.stdin.read()
    else:
        click.echo(f"{RED}Error: provide --text, a file path, or pipe stdin{RESET}", err=True)
        sys.exit(2)

    result = engine.check(input_text, jurisdiction=jurisdiction)

    if json_output:
        _emit_json(result, file_path=target)
    else:
        _print_result(result, verbose=verbose)

    threshold = severity_threshold.lower()
    if any(_meets_threshold(v.severity, threshold) for v in result.violations):
        sys.exit(1)


@cli.group()
def rules() -> None:
    """Manage compliance rules."""
    pass


@rules.command("list")
@click.option("--jurisdiction", "-j", help="Filter by jurisdiction")
@click.pass_context
def rules_list(ctx: click.Context, jurisdiction: Optional[str]) -> None:
    """List all loaded compliance rules."""
    engine = TrustLintEngine(rules_dir=ctx.obj.get("rules_dir"))

    if not engine.rules:
        click.echo(f"{YELLOW}⚠ No rules loaded.{RESET}")
        return

    applicable = engine.rules
    if jurisdiction:
        applicable = [r for r in applicable if r.jurisdiction.upper() == jurisdiction.upper()]

    click.echo(f"\n{BOLD}Loaded Rules ({len(applicable)}){RESET}")
    click.echo(f"{'─' * 70}")
    click.echo(f"{'ID':<40} {'Jurisdiction':<8} {'Severity':<10} {'Category'}")
    click.echo(f"{'─' * 70}")

    for rule in sorted(applicable, key=lambda r: (r.jurisdiction, r.severity, r.id)):
        color = SEVERITY_COLORS.get(rule.severity, "")
        click.echo(
            f"{rule.id:<40} {rule.jurisdiction:<8} "
            f"{color}{rule.severity:<10}{RESET} {rule.category}"
        )

    click.echo(f"\n{DIM}{len(applicable)} rules across "
               f"{len(set(r.jurisdiction for r in applicable))} jurisdictions{RESET}")


@rules.command("update")
def rules_update() -> None:
    """Download the latest rule corpus from GitHub releases."""
    import json
    import os
    import tarfile
    import tempfile
    from pathlib import Path
    from urllib.error import URLError
    from urllib.request import Request, urlopen

    home_rules = Path.home() / ".trustlint" / "rules"
    repo = "ComplyEdge/complyedge"
    api_url = f"https://api.github.com/repos/{repo}/releases/latest"

    click.echo(f"{BOLD}Updating rules from GitHub...{RESET}")

    try:
        headers = {"User-Agent": "trustlint-cli"}
        token = os.getenv("GITHUB_TOKEN")
        if token:
            headers["Authorization"] = f"Bearer {token}"

        req = Request(api_url, headers=headers)
        with urlopen(req, timeout=30) as resp:
            release = json.loads(resp.read().decode("utf-8"))

        tag = release.get("tag_name", "unknown")
        tarball_url = release.get("tarball_url")
        if not tarball_url:
            click.echo(f"{RED}Error: no tarball_url in release{RESET}", err=True)
            sys.exit(2)

        click.echo(f"  Latest release: {tag}")

        req = Request(tarball_url, headers=headers)
        with urlopen(req, timeout=60) as resp:
            with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
                tmp.write(resp.read())
                tmp_path = tmp.name

        home_rules.mkdir(parents=True, exist_ok=True)

        with tarfile.open(tmp_path, "r:gz") as tar:
            for member in tar.getmembers():
                if "/rules/regulations/" in member.name and member.name.endswith(".yaml"):
                    relative = member.name.split("/rules/regulations/", 1)[1]
                    dest = home_rules / relative
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    src = tar.extractfile(member)
                    if src:
                        dest.write_bytes(src.read())

        os.unlink(tmp_path)
        rule_count = sum(1 for _ in home_rules.rglob("*.yaml"))
        click.echo(f"{GREEN}✅ Updated {rule_count} rules to ~/.trustlint/rules/ (release {tag}){RESET}")

    except (URLError, OSError, json.JSONDecodeError) as e:
        click.echo(f"{RED}Error updating rules: {e}{RESET}", err=True)
        sys.exit(2)


@cli.command()
@click.option("--api-key", envvar="COMPLYEDGE_API_KEY", help="API key for Tier 2 LLM analysis")
@click.argument("target", required=False)
@click.option("--text", "-t", help="Text string to check")
def scan(target: Optional[str], text: Optional[str], api_key: Optional[str]) -> None:
    """Run Tier 2 LLM compliance analysis via the ComplyEdge API.

    Requires COMPLYEDGE_API_KEY (env or --api-key flag). Falls back to
    offline regex if the API is unreachable.
    """
    import json
    from urllib.error import URLError
    from urllib.request import Request, urlopen

    if text:
        input_text = text
    elif target:
        path = Path(target)
        if not path.exists():
            click.echo(f"{RED}Error: file not found: {target}{RESET}", err=True)
            sys.exit(2)
        input_text = path.read_text(encoding="utf-8")
    elif not sys.stdin.isatty():
        input_text = sys.stdin.read()
    else:
        click.echo(f"{RED}Error: provide --text, a file path, or pipe stdin{RESET}", err=True)
        sys.exit(2)

    if not api_key:
        click.echo(f"{YELLOW}⚠ No API key set. Set COMPLYEDGE_API_KEY or use --api-key.{RESET}", err=True)
        click.echo(f"{DIM}Falling back to offline regex check (trustlint check).{RESET}", err=True)
        # Fall through to offline check
        engine = TrustLintEngine()
        result = engine.check(input_text)
        _print_result(result, verbose=True)
        if result.has_critical:
            sys.exit(1)
        return

    api_url = "https://api.complyedge.io/v1/check"
    agent_id = os.environ.get("COMPLYEDGE_AGENT_ID", "trustlint-cli")
    payload = json.dumps(
        {
            "text": input_text,
            "agent_id": agent_id,
            "jurisdiction": "EU",
            "direction": "output",
        }
    ).encode()

    try:
        req = Request(api_url, data=payload, headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": "trustlint-cli",
        })
        with urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))

        allowed = data.get("allowed", True)
        violations = data.get("violations", [])
        latency = data.get("latency_ms", 0)

        if allowed:
            click.echo(f"\n{GREEN}{BOLD}✅ PASS{RESET} — no violations ({latency}ms, API)")
        else:
            click.echo(f"\n{RED}{BOLD}❌ BLOCKED{RESET} — {len(violations)} violation(s) ({latency}ms, API)")
            for v in violations:
                click.echo(f"  {RED}[{v.get('severity','?').upper()}]{RESET} {v.get('rule_id','?')}")
                click.echo(f"    {v.get('rule_description','')[:100]}")
            sys.exit(1)

    except (URLError, OSError) as e:
        click.echo(f"{YELLOW}⚠ API unreachable ({e}), falling back to offline check{RESET}", err=True)
        engine = TrustLintEngine()
        result = engine.check(input_text)
        _print_result(result, verbose=True)
        if result.has_critical:
            sys.exit(1)


@cli.command()
@click.option("--force", "-f", is_flag=True, help="Overwrite existing config")
def init(force: bool) -> None:
    """Create a .trustlint.yaml config in the current directory."""
    config_path = Path.cwd() / ".trustlint.yaml"

    if config_path.exists() and not force:
        click.echo(f"{YELLOW}⚠ .trustlint.yaml already exists. Use --force to overwrite.{RESET}")
        return

    config_content = """\
# TrustLint Configuration
# See: https://github.com/ComplyEdge/complyedge

# Rules directory (default: auto-detect from repo or ~/.trustlint/rules/)
# rules_dir: ./rules/regulations

# Default jurisdiction filter (optional)
# jurisdiction: EU

# Severity threshold — only report violations at this level or above
# severity_threshold: medium

# Files to check (glob patterns)
# include:
#   - "**/*.py"
#   - "**/*.ts"
#   - "**/*.yaml"

# Files to skip
# exclude:
#   - "node_modules/**"
#   - ".venv/**"
"""
    config_path.write_text(config_content, encoding="utf-8")
    click.echo(f"{GREEN}✅ Created .trustlint.yaml{RESET}")


def main() -> None:
    cli(obj={})


if __name__ == "__main__":
    main()
