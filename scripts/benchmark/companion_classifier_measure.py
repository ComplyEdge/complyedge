#!/usr/bin/env python3
"""Measure the companion meaning check on a human-labelled set (spec §8 T2).

Calls services/api/companion_classifier.classify in-process. No API, no
tenant, no audit record. Each row is judged three times (three runs), and the
report gives, per run, precision and recall for every label, the rows the model
could not answer, the quote mismatches, and the measured cost per check from
the run's own spend counter (llm_budget settles each call at its real token
cost) plus the mean prompt, cached and completion tokens.

THE LABELLED SET. A JSONL file, one row per line:

    {"text": "...", "direction": "prompt" | "output",
     "labels": ["expresses_self_harm", ...],
     "reviewer": "<who labelled it>", "signed_off_at": "<ISO date>"}

The labels are the answer key, so they come from a human reviewer, never from
the model under test (§11 D3; intent C2 execution_oracle). A row without
reviewer or signed_off_at refuses the WHOLE set: a measurement on a partly
signed set would read as evidence it is not. Codes must exist in
companion_labels.yaml for the row's direction.

COST GATE. Nothing is sent to the model unless --run is given AND the operator
types the projected worst-case cost back at the prompt. Without --run the
script validates the set, prints the projection and exits. The run is also
hard-capped at that projected amount through llm_budget.run_budget.

Usage:

    .venv/bin/python scripts/benchmark/companion_classifier_measure.py SET.jsonl
    set -a; . ./.env; set +a
    .venv/bin/python scripts/benchmark/companion_classifier_measure.py SET.jsonl --run

Writes scripts/benchmark/results/companion_classifier_measure_latest.json on --run.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import statistics
import sys
from collections.abc import Iterable, Sequence
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "services" / "api"))

OUT = (
    Path(__file__).resolve().parent
    / "results"
    / "companion_classifier_measure_latest.json"
)

RUNS = 3

_usage: list[dict] = []


class LabelledSetError(ValueError):
    """The labelled set cannot be measured as it stands."""


def load_set(path: Path) -> list[dict[str, Any]]:
    """Read and validate the labelled set. Raises LabelledSetError listing
    every bad line, so the reviewer can fix them in one pass."""
    import companion_classifier as clf

    allowed = {d: {lb.code for lb in clf.labels_for(d)} for d in clf.DIRECTION_TO_ON}
    rows: list[dict[str, Any]] = []
    problems: list[str] = []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as e:
            problems.append(f"line {n}: not JSON ({e.msg})")
            continue
        if not isinstance(row, dict):
            problems.append(f"line {n}: not an object")
            continue
        if (
            not str(row.get("reviewer") or "").strip()
            or not str(row.get("signed_off_at") or "").strip()
        ):
            problems.append(
                f"line {n}: no reviewer or signed_off_at (labels must be signed off by a human reviewer)"
            )
            continue
        direction = row.get("direction")
        if direction not in allowed:
            problems.append(f"line {n}: direction must be prompt or output")
            continue
        if not isinstance(row.get("text"), str) or not row["text"].strip():
            problems.append(f"line {n}: no text")
            continue
        labels = row.get("labels")
        if not isinstance(labels, list):
            problems.append(f"line {n}: labels must be a list (empty for a clean row)")
            continue
        unknown = sorted(set(map(str, labels)) - allowed[direction])
        if unknown:
            problems.append(f"line {n}: codes not defined for {direction}: {unknown}")
            continue
        rows.append(
            {
                "line": n,
                "text": row["text"],
                "direction": direction,
                "labels": sorted(set(map(str, labels))),
            }
        )
    if problems:
        raise LabelledSetError("\n".join(problems))
    if not rows:
        raise LabelledSetError("the set has no rows")
    return rows


def projected_micros(
    rows: Sequence[dict[str, Any]], model: str, runs: int = RUNS
) -> int:
    """Worst-case spend of the measurement: every row, every run, priced with
    the same bound the API reserves (companion_classifier.worst_case_micros)."""
    import companion_classifier as clf

    return runs * sum(
        clf.worst_case_micros(r["text"], r["direction"], model=model) for r in rows
    )


def _ratio(num: int, den: int) -> float | None:
    return round(num / den, 4) if den else None


def score(
    rows: Sequence[dict[str, Any]], predictions: Iterable[dict[str, Any]]
) -> dict[str, Any]:
    """Offline scoring of ONE run. `predictions` is one dict per row, in row
    order: {"available": bool, "labels": [codes], "quote_mismatch": [codes]}.

    Per label, over the rows of that label's direction: tp, fp, fn, precision,
    recall. A row the model could not answer counts as predicting nothing, so
    its expected labels are misses: a missing answer is never a pass (C7)."""
    import companion_classifier as clf

    on_of = {lb.code: lb.on for lb in clf.load_labels()}
    preds = list(predictions)
    if len(preds) != len(rows):
        raise ValueError(f"{len(preds)} predictions for {len(rows)} rows")
    counts: dict[str, dict[str, int]] = {}
    unavailable = 0
    mismatches = 0
    for row, pred in zip(rows, preds, strict=True):
        expected = set(row["labels"])
        got = set(pred.get("labels") or ()) if pred.get("available") else set()
        if not pred.get("available"):
            unavailable += 1
        mismatches += len(pred.get("quote_mismatch") or ())
        for code in expected | got:
            c = counts.setdefault(code, {"tp": 0, "fp": 0, "fn": 0})
            if code in expected and code in got:
                c["tp"] += 1
            elif code in got:
                c["fp"] += 1
            else:
                c["fn"] += 1
    per_label = {
        code: {
            "on": on_of.get(code),
            **c,
            "precision": _ratio(c["tp"], c["tp"] + c["fp"]),
            "recall": _ratio(c["tp"], c["tp"] + c["fn"]),
        }
        for code, c in sorted(counts.items())
    }
    return {
        "rows": len(rows),
        "unavailable": unavailable,
        "quote_mismatches": mismatches,
        "labels": per_label,
    }


def _capture_usage(_, __, event_dict):
    import structlog

    if event_dict.get("event") == "LLM API call completed" and event_dict.get("usage"):
        _usage.append(event_dict["usage"])
    raise structlog.DropEvent


def _mean(values: list[int]) -> float | None:
    return round(statistics.mean(values), 1) if values else None


async def _one_run(
    rows: Sequence[dict[str, Any]], model: str, concurrency: int
) -> list[dict]:
    import companion_classifier as clf

    sem = asyncio.Semaphore(concurrency)

    async def one(row: dict[str, Any]) -> dict:
        async with sem:
            v = await clf.classify(row["text"], row["direction"], model=model)
        # Codes only: the verdict never carries quotes, and neither does the report.
        return {
            "available": v.available,
            "labels": list(v.labels),
            "quote_mismatch": list(v.quote_mismatch),
            "reason": v.reason,
        }

    return list(await asyncio.gather(*(one(r) for r in rows)))


def _measure(
    rows: Sequence[dict[str, Any]], model: str, concurrency: int, cap_micros: int
) -> dict:
    import llm_budget

    runs = []
    total_spent = 0
    for i in range(RUNS):
        budget = llm_budget.run_budget(f"{OUT.stem}-{i + 1}", cap_micros / 1_000_000)
        start = len(_usage)
        with llm_budget.bound(budget):
            preds = asyncio.run(_one_run(rows, model, concurrency))
        spent = budget.store.spent(budget.tenant_id, budget.period)
        total_spent += spent
        usage = _usage[start:]
        report = score(rows, preds)
        report.update(
            {
                "run": i + 1,
                "llm_calls": len(usage),
                "spent_usd": round(spent / 1_000_000, 6),
                "cost_per_check_usd": round(spent / len(rows) / 1_000_000, 8),
                "prompt_tokens_mean": _mean([u.get("prompt_tokens", 0) for u in usage]),
                "cached_tokens_mean": _mean(
                    [
                        (u.get("prompt_tokens_details") or {}).get("cached_tokens", 0)
                        for u in usage
                    ]
                ),
                "completion_tokens_mean": _mean(
                    [u.get("completion_tokens", 0) for u in usage]
                ),
                "predictions": [
                    {"line": r["line"], "expected": r["labels"], **p}
                    for r, p in zip(rows, preds, strict=True)
                ],
            }
        )
        runs.append(report)
    from adcr_record import utc_timestamp

    return {
        "model": model,
        "run_at": utc_timestamp(datetime.now(UTC)),
        "rows": len(rows),
        "runs": runs,
        "spent_usd_total": round(total_spent / 1_000_000, 6),
        "cost_per_check_usd": round(total_spent / (len(rows) * RUNS) / 1_000_000, 8),
    }


def main(argv: Sequence[str] | None = None) -> int:
    import companion_classifier as clf

    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("labelled_set", type=Path, help="JSONL labelled set (human signed)")
    ap.add_argument("--model", default=clf.COMPANION_MODEL)
    ap.add_argument("--concurrency", type=int, default=4)
    ap.add_argument(
        "--run",
        action="store_true",
        help="make the paid model calls (asks you to type the projected cost first)",
    )
    args = ap.parse_args(argv)

    try:
        rows = load_set(args.labelled_set)
    except LabelledSetError as e:
        print(f"REFUSED: the labelled set cannot be measured:\n{e}", file=sys.stderr)
        return 2

    worst = projected_micros(rows, args.model)
    worst_usd = f"{math.ceil(worst) / 1_000_000:.6f}"
    calls = RUNS * sum(len(clf.chunks(r["text"])) for r in rows)
    by_dir = {d: sum(r["direction"] == d for r in rows) for d in clf.DIRECTION_TO_ON}
    print(
        f"{len(rows)} rows ({by_dir['prompt']} messages, {by_dir['output']} replies) "
        f"x {RUNS} runs = {calls} calls to {args.model}"
    )
    print(
        f"Projected worst-case cost: ${worst_usd} (no cache hit assumed; the run is capped at this)"
    )
    if not args.run:
        print("No model call made. Add --run to measure.")
        return 0

    try:
        answer = input(
            f"Type the projected cost to run  [{worst_usd} = send all {calls} calls "
            "· anything else = abort, nothing sent]: "
        )
    except EOFError:
        answer = ""
    if answer.strip() != worst_usd:
        print("Aborted: no model call made.")
        return 1

    import structlog

    structlog.configure(processors=[_capture_usage])
    report = _measure(rows, args.model, args.concurrency, worst // RUNS + 1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    for run in report["runs"]:
        print(
            f"run {run['run']}: unavailable {run['unavailable']}/{run['rows']}, "
            f"quote mismatches {run['quote_mismatches']}, "
            f"cost/check ${run['cost_per_check_usd']}, cached tokens mean {run['cached_tokens_mean']}"
        )
        for code, m in run["labels"].items():
            print(
                f"  {code:<38} {m['on'] or '?':<7} tp={m['tp']:<3} fp={m['fp']:<3} "
                f"fn={m['fn']:<3} precision={m['precision']} recall={m['recall']}"
            )
    print(
        f"Total spent ${report['spent_usd_total']}, cost per check ${report['cost_per_check_usd']}"
    )
    print(f"Wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
