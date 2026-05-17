"""GPAI Compliance Benchmark — leaderboard renderer.

Reads benchmark_runner JSON output and produces a Markdown leaderboard.

Usage:
    python scripts/benchmark/leaderboard_renderer.py \
        --input scripts/benchmark/results/benchmark_latest.json \
        --markdown scripts/benchmark/results/leaderboard.md
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

OBLIGATION_LABELS = {
    "art_50_2_content_disclosure": "Art 50(2) Disclosure",
    "art_51_model_classification": "Art 51 Classification",
    "art_52_53_1_a_b_technical_documentation": "Art 52/53(1)(a-b) Tech Docs",
    "art_53_1_c_copyright_transparency": "Art 53(1)(c) Copyright",
    "art_53_1_d_e_downstream_obligations": "Art 53(1)(d-e) Downstream",
    "art_55_systemic_risk": "Art 55 Systemic Risk",
}


def cell(score_obj: dict) -> str:
    if not score_obj.get("applicable", True):
        return "N/A"
    return str(score_obj["score"])


def render_markdown(data: dict) -> str:
    lines: list[str] = []
    lines.append("# GPAI Compliance Benchmark — Leaderboard")
    lines.append("")
    lines.append(f"_Generated: {data['generated_at']}_")
    lines.append(f"_Methodology: v{data['methodology_version']} "
                 f"([docs/research/gpai_benchmark_methodology.md](../../docs/research/gpai_benchmark_methodology.md))_")
    lines.append("")

    s = data["summary"]
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- **Providers scored:** {s['total_scored']}")
    lines.append(f"- **Providers pending:** {s['total_pending']}")
    lines.append(f"- **Average compliance:** {s['avg_compliance_pct']}%")
    if s["best"]:
        lines.append(f"- **Highest score:** `{s['best']}`")
    if s["worst"]:
        lines.append(f"- **Lowest score:** `{s['worst']}`")
    lines.append("")

    lines.append("## Leaderboard")
    lines.append("")
    headers = (
        ["Rank", "Provider", "Class"]
        + list(OBLIGATION_LABELS.values())
        + ["Aggregate", "% Compliance", "Status"]
    )
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("| " + " | ".join(["---"] * len(headers)) + " |")

    for rank, row in enumerate(data["scored_providers"], start=1):
        per = row["per_obligation"]
        cells = [
            str(rank),
            f"**{row['provider_name']}**",
            row["model_class"],
        ]
        for key in OBLIGATION_LABELS:
            cells.append(cell(per[key]))
        cells.append(f"{row['aggregate_score']} / {row['max_score']}")
        cells.append(f"{row['compliance_pct']}%")
        cells.append(row["verification_status"])
        lines.append("| " + " | ".join(cells) + " |")

    lines.append("")

    if data["pending_providers"]:
        lines.append("## Pending (research not yet complete)")
        lines.append("")
        for pid in data["pending_providers"]:
            lines.append(f"- `{pid}`")
        lines.append("")

    stale_rows = [
        (r["provider_id"], r["stale_evidence"])
        for r in data["scored_providers"]
        if r.get("stale_evidence")
    ]
    if stale_rows:
        lines.append("## Stale evidence (>180 days)")
        lines.append("")
        for pid, items in stale_rows:
            lines.append(f"### `{pid}`")
            for item in items:
                lines.append(f"- {item}")
            lines.append("")

    lines.append("## Scoring rubric")
    lines.append("")
    lines.append("| Score | Label | Standard |")
    lines.append("| --- | --- | --- |")
    lines.append("| 0 | No evidence | Provider does not address the obligation publicly. |")
    lines.append("| 1 | Partial | Mentioned without verifiable detail. |")
    lines.append("| 2 | Adequate | Specific, sourced documentation exists. |")
    lines.append("| 3 | Exceeds | Machine-readable, regularly updated, audited. |")
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent.parent
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--input",
        type=Path,
        default=repo_root / "scripts/benchmark/results/benchmark_latest.json",
    )
    parser.add_argument(
        "--markdown",
        type=Path,
        default=repo_root / "scripts/benchmark/results/leaderboard.md",
    )
    args = parser.parse_args()

    with args.input.open() as f:
        data = json.load(f)

    markdown = render_markdown(data)
    args.markdown.parent.mkdir(parents=True, exist_ok=True)
    args.markdown.write_text(markdown)
    print(f"Rendered {len(data['scored_providers'])} providers to {args.markdown}")


if __name__ == "__main__":
    main()
