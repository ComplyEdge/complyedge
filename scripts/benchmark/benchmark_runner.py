"""GPAI Compliance Benchmark — runner.

Loads provider evidence YAML files from a directory, validates them
against the schema, computes per-provider and aggregate scores across
the six EU AI Act GPAI obligation categories, and writes a JSON result.

Usage:
    python scripts/benchmark/benchmark_runner.py \
        --providers providers/ \
        --schema scripts/benchmark/provider_schema.yaml \
        --output scripts/benchmark/results/benchmark_latest.json
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft7Validator

OBLIGATION_KEYS = [
    "art_50_2_content_disclosure",
    "art_51_model_classification",
    "art_52_53_1_a_b_technical_documentation",
    "art_53_1_c_copyright_transparency",
    "art_53_1_d_e_downstream_obligations",
    "art_55_systemic_risk",
]


def _strip_yaml_anchors(schema: dict) -> dict:
    """Remove top-level $schema/title which jsonschema does not need."""
    out = {k: v for k, v in schema.items() if k not in ("$schema", "title")}
    return out


def load_schema(schema_path: Path) -> dict:
    with schema_path.open() as f:
        return yaml.safe_load(f)


def load_providers(providers_dir: Path) -> list[tuple[Path, dict]]:
    files = sorted(providers_dir.glob("*.yaml")) + sorted(providers_dir.glob("*.yml"))
    out: list[tuple[Path, dict]] = []
    for f in files:
        with f.open() as fh:
            out.append((f, yaml.safe_load(fh)))
    return out


def validate(provider: dict, schema: dict, path: Path) -> list[str]:
    validator = Draft7Validator(schema)
    return [
        f"{path.name}: {'.'.join(str(p) for p in err.absolute_path)}: {err.message}"
        for err in validator.iter_errors(provider)
    ]


def score_provider(provider: dict) -> dict[str, Any]:
    """Compute per-obligation scores and aggregate for one provider."""
    is_systemic = bool(provider.get("systemic_risk_threshold", False))
    obligations = provider["obligations"]

    per_obligation = {}
    total = 0
    max_score = 0
    for key in OBLIGATION_KEYS:
        is_art55 = key == "art_55_systemic_risk"
        if is_art55 and not is_systemic:
            per_obligation[key] = {"score": None, "applicable": False}
            continue
        score = int(obligations[key]["score"])
        per_obligation[key] = {"score": score, "applicable": True}
        total += score
        max_score += 3

    return {
        "provider_id": provider["provider_id"],
        "provider_name": provider["provider_name"],
        "model_class": provider["model_class"],
        "systemic_risk_threshold": is_systemic,
        "verification_status": provider["verification_status"],
        "last_updated": provider["last_updated"],
        "per_obligation": per_obligation,
        "aggregate_score": total,
        "max_score": max_score,
        "compliance_pct": round((total / max_score * 100), 1) if max_score else 0.0,
    }


def flag_stale_evidence(provider: dict, threshold_days: int = 180) -> list[str]:
    today = date.today()
    stale: list[str] = []
    for ob_key, ob in provider["obligations"].items():
        for i, e in enumerate(ob.get("evidence", [])):
            verified = date.fromisoformat(e["verified_date"])
            age = (today - verified).days
            if age > threshold_days:
                stale.append(f"{ob_key}[{i}] verified {age} days ago — {e['url']}")
    return stale


def run(providers_dir: Path, schema_path: Path, output_path: Path) -> dict[str, Any]:
    schema = _strip_yaml_anchors(load_schema(schema_path))
    providers = load_providers(providers_dir)

    if not providers:
        raise SystemExit(f"no provider files found in {providers_dir}")

    all_errors: list[str] = []
    scored: list[dict[str, Any]] = []
    pending: list[str] = []

    for path, provider in providers:
        errs = validate(provider, schema, path)
        if errs:
            all_errors.extend(errs)
            continue

        if provider["verification_status"] == "pending":
            pending.append(provider["provider_id"])
            continue

        result = score_provider(provider)
        result["stale_evidence"] = flag_stale_evidence(provider)
        scored.append(result)

    if all_errors:
        for e in all_errors:
            print(f"  SCHEMA ERROR: {e}", file=sys.stderr)
        raise SystemExit(f"validation failed: {len(all_errors)} error(s)")

    scored.sort(key=lambda r: r["aggregate_score"], reverse=True)

    output = {
        "generated_at": datetime.now(UTC).isoformat(),
        "methodology_version": "1.0",
        "scored_providers": scored,
        "pending_providers": sorted(pending),
        "summary": {
            "total_scored": len(scored),
            "total_pending": len(pending),
            "avg_compliance_pct": (
                round(sum(r["compliance_pct"] for r in scored) / len(scored), 1)
                if scored
                else 0.0
            ),
            "best": scored[0]["provider_id"] if scored else None,
            "worst": scored[-1]["provider_id"] if scored else None,
        },
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w") as f:
        json.dump(output, f, indent=2)

    return output


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent.parent
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--providers", type=Path, default=repo_root / "providers")
    parser.add_argument(
        "--schema",
        type=Path,
        default=repo_root / "scripts/benchmark/provider_schema.yaml",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=repo_root / "scripts/benchmark/results/benchmark_latest.json",
    )
    args = parser.parse_args()

    result = run(args.providers, args.schema, args.output)
    s = result["summary"]
    print(f"Scored {s['total_scored']} providers, {s['total_pending']} pending.")
    print(f"Average compliance: {s['avg_compliance_pct']}%")
    if s["best"]:
        print(f"Best:  {s['best']}")
    if s["worst"]:
        print(f"Worst: {s['worst']}")
    print(f"Output: {args.output}")


if __name__ == "__main__":
    main()
