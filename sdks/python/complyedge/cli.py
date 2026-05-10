"""
ComplyEdge CLI — cloud-connected compliance commands.

Commands:
  complyedge login    — Authenticate and store API key
  complyedge scan     — Run compliance check via API
  complyedge status   — Show current config and API health
  complyedge rules    — List loaded compliance rules
"""

from __future__ import annotations

import json
import sys
import webbrowser
from pathlib import Path
from typing import Optional

import click

from complyedge import __version__

# ANSI colors
RED = "\033[91m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
CYAN = "\033[96m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

CONFIG_DIR = Path.home() / ".complyedge"
CONFIG_FILE = CONFIG_DIR / "config.json"


def _load_config() -> dict:
    if CONFIG_FILE.exists():
        return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    return {}


def _save_config(config: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(config, indent=2), encoding="utf-8")
    CONFIG_FILE.chmod(0o600)  # Owner-only read/write


def _get_api_key() -> Optional[str]:
    import os
    key = os.getenv("COMPLYEDGE_API_KEY")
    if key:
        return key
    config = _load_config()
    return config.get("api_key")


def _mask_key(key: str) -> str:
    if len(key) <= 8:
        return "***"
    return f"{key[:6]}...{key[-4:]}"


@click.group()
@click.version_option(version=__version__, prog_name="complyedge")
def cli() -> None:
    """ComplyEdge — runtime compliance enforcement for AI agents."""
    pass


@cli.command()
@click.option("--api-key", prompt="API Key", hide_input=True,
              help="Your ComplyEdge API key (or paste when prompted)")
@click.option("--base-url", default=None, help="API base URL (default: https://api.complyedge.io)")
def login(api_key: str, base_url: Optional[str]) -> None:
    """Authenticate and store your API key locally.

    Your API key is stored in ~/.complyedge/config.json (owner-only permissions).
    """
    config = _load_config()
    config["api_key"] = api_key.strip()
    if base_url:
        config["base_url"] = base_url.strip()
    _save_config(config)

    click.echo(f"\n{GREEN}{BOLD}Logged in.{RESET} API key saved to {CONFIG_FILE}")
    click.echo(f"{DIM}Key: {_mask_key(api_key)}{RESET}")


@cli.command()
def signup() -> None:
    """Open the ComplyEdge sign-up page in your browser."""
    url = "https://complyedge.io/signup"
    click.echo(f"Opening {url} ...")
    webbrowser.open(url)


def _create_client(api_key: str, base_url: Optional[str] = None):
    from complyedge import ComplyEdge
    return ComplyEdge(api_key=api_key, base_url=base_url) if base_url else ComplyEdge(api_key=api_key)


@cli.command()
@click.argument("target", required=False)
@click.option("--text", "-t", help="Text string to scan")
@click.option("--jurisdiction", "-j", default="US", help="Jurisdiction (EU, US, GLOBAL)")
@click.option("--verbose", "-v", is_flag=True, help="Show full violation details")
def scan(target: Optional[str], text: Optional[str], jurisdiction: str, verbose: bool) -> None:
    """Run a compliance check via the ComplyEdge API.

    Examples:

      complyedge scan --text "We expect revenue to increase by 25%"

      complyedge scan prompt.txt --jurisdiction EU

      echo "social credit score" | complyedge scan
    """
    api_key = _get_api_key()
    if not api_key:
        click.echo(f"{RED}No API key found. Run 'complyedge login' or set COMPLYEDGE_API_KEY.{RESET}", err=True)
        sys.exit(2)

    # Resolve input text
    if text:
        input_text = text
    elif target:
        path = Path(target)
        if not path.exists():
            click.echo(f"{RED}File not found: {target}{RESET}", err=True)
            sys.exit(2)
        input_text = path.read_text(encoding="utf-8")
    elif not sys.stdin.isatty():
        input_text = sys.stdin.read()
    else:
        click.echo(f"{RED}Provide --text, a file path, or pipe stdin.{RESET}", err=True)
        sys.exit(2)

    # Make API call
    config = _load_config()
    base_url = config.get("base_url")

    try:
        ce = _create_client(api_key, base_url)
        result = ce.check(input_text, jurisdiction=jurisdiction)
    except Exception as e:
        click.echo(f"{RED}API error: {e}{RESET}", err=True)
        sys.exit(2)

    # Display results
    if result.safe:
        click.echo(f"\n{GREEN}{BOLD}COMPLIANT{RESET} — no violations detected")
        click.echo(f"{DIM}Jurisdiction: {jurisdiction} | Event: {result.event_id}{RESET}")
        sys.exit(0)
    else:
        click.echo(f"\n{BOLD}Compliance Violations Found{RESET}")
        click.echo(f"{'─' * 50}")
        for v in result.violations:
            severity_color = RED if v.severity in ("critical", "high") else YELLOW
            click.echo(f"\n{severity_color}{BOLD}[{v.severity.upper()}]{RESET} {v.rule_id}")
            click.echo(f"  {v.rule_description}")
            if verbose and v.reason:
                click.echo(f"  {CYAN}Reason: {v.reason}{RESET}")
        click.echo(f"\n{'─' * 50}")
        critical = sum(1 for v in result.violations if v.severity in ("critical", "high"))
        click.echo(f"{RED}{critical} critical/high{RESET} violations | Event: {result.event_id}")
        sys.exit(1)


@cli.command()
def status() -> None:
    """Show current configuration and API health."""
    import os

    import httpx

    api_key = _get_api_key()
    config = _load_config()
    base_url = config.get("base_url") or os.getenv("COMPLYEDGE_API_URL") or "https://api.complyedge.io"

    click.echo(f"\n{BOLD}ComplyEdge v{__version__}{RESET}")
    click.echo(f"{'─' * 40}")

    if api_key:
        click.echo(f"API Key:  {_mask_key(api_key)}")
        source = "env" if os.getenv("COMPLYEDGE_API_KEY") else "~/.complyedge/config.json"
        click.echo(f"Source:   {source}")
    else:
        click.echo(f"{YELLOW}API Key:  not configured{RESET}")
        click.echo(f"{DIM}Run 'complyedge login' or set COMPLYEDGE_API_KEY{RESET}")

    click.echo(f"API URL:  {base_url}")

    # Health check
    try:
        resp = httpx.get(f"{base_url}/health", timeout=5)
        if resp.status_code == 200:
            click.echo(f"Health:   {GREEN}healthy{RESET}")
        else:
            click.echo(f"Health:   {YELLOW}degraded (HTTP {resp.status_code}){RESET}")
    except Exception:
        click.echo(f"Health:   {RED}unreachable{RESET}")


@cli.command("pre-deploy")
@click.option("--file", "-f", "config_file", required=True,
              help="Path to YAML or JSON agent configuration file")
@click.option("--api-key", envvar="COMPLYEDGE_API_KEY", default=None,
              help="API key (or set COMPLYEDGE_API_KEY)")
@click.option("--jurisdiction", "-j", default="EU", help="Jurisdiction (default: EU)")
@click.option("--verbose", "-v", is_flag=True, help="Show full violation details")
def pre_deploy(config_file: str, api_key: Optional[str], jurisdiction: str, verbose: bool) -> None:
    """Assess an AI system configuration BEFORE deployment.

    Reads a YAML or JSON agent config and evaluates it against EU AI Act requirements.

    Examples:

      complyedge pre-deploy --file agent_config.yaml

      complyedge pre-deploy -f config.json --jurisdiction EU -v
    """
    api_key = api_key or _get_api_key()
    if not api_key:
        click.echo(f"{RED}No API key found. Run 'complyedge login' or set COMPLYEDGE_API_KEY.{RESET}", err=True)
        sys.exit(2)

    path = Path(config_file)
    if not path.exists():
        click.echo(f"{RED}File not found: {config_file}{RESET}", err=True)
        sys.exit(2)

    # Parse config file
    raw = path.read_text(encoding="utf-8")
    try:
        if path.suffix in (".yaml", ".yml"):
            import yaml
            config_data = yaml.safe_load(raw)
        else:
            config_data = json.loads(raw)
    except Exception as e:
        click.echo(f"{RED}Failed to parse {config_file}: {e}{RESET}", err=True)
        sys.exit(2)

    system_prompt = config_data.get("system_prompt", "")
    if not system_prompt:
        click.echo(f"{RED}Config must include 'system_prompt' field.{RESET}", err=True)
        sys.exit(2)

    model_config = config_data.get("model_config")
    agent_pipeline = config_data.get("agent_pipeline")

    # Make API call
    config = _load_config()
    base_url = config.get("base_url")

    try:
        ce = _create_client(api_key, base_url)
        result = ce.assess_pre_deployment(
            system_prompt=system_prompt,
            model_config=model_config,
            agent_pipeline=agent_pipeline,
            jurisdiction=jurisdiction,
        )
    except Exception as e:
        click.echo(f"{RED}API error: {e}{RESET}", err=True)
        sys.exit(2)

    # Display results
    risk_tier = result.get("risk_tier", "unknown")
    score = result.get("compliance_score", 0)
    violations = result.get("violations", [])
    disclosures = result.get("required_disclosures", [])
    category = result.get("eu_ai_act_category", "")
    deadline = result.get("estimated_deadline", "")

    tier_colors = {
        "minimal": GREEN, "limited": CYAN, "high": YELLOW, "unacceptable": RED,
    }
    tier_color = tier_colors.get(risk_tier, RED)

    click.echo(f"\n{BOLD}Pre-Deployment Assessment{RESET}")
    click.echo(f"{'─' * 50}")
    click.echo(f"Risk Tier:        {tier_color}{BOLD}{risk_tier.upper()}{RESET}")
    click.echo(f"Compliance Score: {score:.0%}")
    click.echo(f"EU AI Act Class:  {category}")
    if deadline:
        click.echo(f"Compliance By:    {deadline}")

    if violations:
        click.echo(f"\n{BOLD}Violations ({len(violations)}){RESET}")
        for v in violations:
            click.echo(f"\n  {RED}{BOLD}[{v.get('article', '')}]{RESET} {v.get('rule_id', '')}")
            click.echo(f"  {v.get('description', '')}")
            if verbose:
                click.echo(f"  {CYAN}Action: {v.get('required_action', '')}{RESET}")

    if disclosures:
        click.echo(f"\n{BOLD}Required Disclosures ({len(disclosures)}){RESET}")
        for d in disclosures:
            click.echo(f"  {YELLOW}• {d}{RESET}")

    click.echo(f"\n{'─' * 50}")
    if risk_tier == "unacceptable":
        click.echo(f"{RED}{BOLD}BLOCKED — system uses prohibited AI practices{RESET}")
        sys.exit(1)
    elif risk_tier == "high":
        click.echo(f"{YELLOW}{BOLD}HIGH RISK — compliance obligations apply{RESET}")
        sys.exit(1) if violations else sys.exit(0)
    elif violations:
        click.echo(f"{YELLOW}Issues found — review before deployment{RESET}")
        sys.exit(1)
    else:
        click.echo(f"{GREEN}{BOLD}PASS — ready for deployment{RESET}")
        sys.exit(0)


@cli.command("rules")
def rules_info() -> None:
    """Show loaded compliance rules from the API."""
    api_key = _get_api_key()
    if not api_key:
        click.echo(f"{RED}No API key. Run 'complyedge login' first.{RESET}", err=True)
        sys.exit(2)

    config = _load_config()
    base_url = config.get("base_url")

    try:
        import httpx
        url = (base_url or "https://api.complyedge.io").rstrip("/")
        resp = httpx.get(
            f"{url}/v1/rules/info",
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=10,
        )
        if resp.status_code != 200:
            click.echo(f"{RED}API error: {resp.status_code}{RESET}", err=True)
            sys.exit(2)

        data = resp.json()
        click.echo(f"\n{BOLD}Loaded Rules{RESET}")
        click.echo(f"Bundle:        {data.get('bundle_id', 'n/a')}")
        click.echo(f"Version:       {data.get('version', 'n/a')}")
        click.echo(f"Rule count:    {data.get('rule_count', 'n/a')}")
        click.echo(f"Jurisdictions: {', '.join(data.get('jurisdictions', []))}")
        click.echo(f"Generated:     {data.get('generated_at', 'n/a')}")

    except Exception as e:
        click.echo(f"{RED}Error: {e}{RESET}", err=True)
        sys.exit(2)


def main() -> None:
    cli()


if __name__ == "__main__":
    main()
