#!/usr/bin/env python3
"""Sign the companion labelled set with a spreadsheet.

The answer key of the measurement (companion_classifier_measure.py) comes from
a person, never from a model. This turns the unsigned candidate rows into a
sheet that person fills in, and turns the filled sheet into the signed set.

    export   candidates.jsonl -> sheet.csv   (one row per message or reply)
    import   sheet.csv        -> companion_labelled_set.jsonl, signed

The reviewer fills two columns and may fill a third:

    final_labels   the label codes that apply, separated by spaces. It starts
                   as the proposal. Empty means a clean row.
    reviewed       "x" once the reviewer has read the row. A row without it is
                   refused, so nobody signs a row they did not read.
    ambiguous      "x" when the row cannot be called either way. It is kept
                   and reported apart, never a hit or a miss.

Import refuses the whole sheet and lists every bad row when a row is unread, a
code is not defined for the row's direction, the text was edited, or a row was
added or removed. Nothing is written until the sheet is clean.

No model call and no network: this only reads and writes local files.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import date
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "services" / "api"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

COLUMNS = [
    "id",
    "direction",
    "category",
    "needs_judgement",
    "text",
    "proposed_labels",
    "final_labels",
    "ambiguous",
    "reviewed",
]
YES = {"x", "y", "yes", "true", "1"}


class SheetError(ValueError):
    """The sheet cannot be signed as it stands."""


def read_candidates(path: Path) -> list[dict[str, Any]]:
    rows = [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    ids = [r["id"] for r in rows]
    if len(set(ids)) != len(ids):
        raise SheetError("the candidates file has a repeated id")
    return rows


def export_sheet(candidates: Path, sheet: Path) -> int:
    rows = read_candidates(candidates)
    with sheet.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        for r in rows:
            proposed = " ".join(r.get("proposed_labels") or [])
            w.writerow(
                {
                    "id": r["id"],
                    "direction": r["direction"],
                    "category": r.get("category", ""),
                    "needs_judgement": "yes" if r.get("needs_judgement") else "",
                    "text": r["text"],
                    "proposed_labels": proposed,
                    "final_labels": proposed,
                    "ambiguous": "",
                    "reviewed": "",
                }
            )
    return len(rows)


def allowed_codes() -> dict[str, set[str]]:
    import companion_classifier as clf

    return {d: {lb.code for lb in clf.labels_for(d)} for d in clf.DIRECTION_TO_ON}


def signed_rows(
    candidates: Path, sheet: Path, reviewer: str, signed_off_at: str
) -> list[dict[str, Any]]:
    """The signed set the sheet describes. Raises SheetError naming every bad row."""
    if not reviewer.strip():
        raise SheetError("no reviewer name")
    source = {r["id"]: r for r in read_candidates(candidates)}
    allowed = allowed_codes()
    with sheet.open(encoding="utf-8", newline="") as f:
        filled = list(csv.DictReader(f))
    problems: list[str] = []
    seen: set[str] = set()
    out: list[dict[str, Any]] = []
    for n, row in enumerate(filled, 2):  # line 1 is the header
        rid = (row.get("id") or "").strip()
        src = source.get(rid)
        if src is None:
            problems.append(f"line {n}: id {rid!r} is not in the candidates file")
            continue
        if rid in seen:
            problems.append(f"line {n}: id {rid} appears twice")
            continue
        seen.add(rid)
        if (row.get("text") or "") != src["text"]:
            problems.append(f"line {n} ({rid}): the text was changed")
            continue
        if (row.get("reviewed") or "").strip().lower() not in YES:
            problems.append(f"line {n} ({rid}): not marked reviewed")
            continue
        labels = sorted(set((row.get("final_labels") or "").replace(",", " ").split()))
        unknown = sorted(set(labels) - allowed[src["direction"]])
        if unknown:
            problems.append(
                f"line {n} ({rid}): codes not defined for {src['direction']}: {unknown}"
            )
            continue
        signed: dict[str, Any] = {
            "id": rid,
            "text": src["text"],
            "direction": src["direction"],
            "category": src.get("category", ""),
            "labels": labels,
            "reviewer": reviewer.strip(),
            "signed_off_at": signed_off_at,
        }
        if (row.get("ambiguous") or "").strip().lower() in YES:
            signed["ambiguous"] = True
        out.append(signed)
    missing = sorted(set(source) - seen)
    if missing:
        shown = ", ".join(missing[:10]) + (" ..." if len(missing) > 10 else "")
        problems.append(
            f"{len(missing)} candidate rows are missing from the sheet: {shown}"
        )
    if problems:
        raise SheetError("\n".join(problems))
    return out


def import_sheet(
    candidates: Path, sheet: Path, out: Path, reviewer: str, signed_off_at: str
) -> int:
    rows = signed_rows(candidates, sheet, reviewer, signed_off_at)
    out.write_text(
        "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows),
        encoding="utf-8",
    )
    return len(rows)


def main(argv: list[str] | None = None) -> int:
    fixtures = ROOT / "tests" / "fixtures"
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    ex = sub.add_parser("export", help="write the sheet the reviewer fills in")
    ex.add_argument(
        "--candidates",
        type=Path,
        default=fixtures / "companion_labelled_set.candidates.jsonl",
    )
    ex.add_argument("--sheet", type=Path, required=True)
    im = sub.add_parser("import", help="turn the filled sheet into the signed set")
    im.add_argument(
        "--candidates",
        type=Path,
        default=fixtures / "companion_labelled_set.candidates.jsonl",
    )
    im.add_argument("--sheet", type=Path, required=True)
    im.add_argument(
        "--out", type=Path, default=fixtures / "companion_labelled_set.jsonl"
    )
    im.add_argument(
        "--reviewer", required=True, help="name of the person who read every row"
    )
    im.add_argument(
        "--date", default=date.today().isoformat(), help="sign-off date, ISO"
    )
    args = ap.parse_args(argv)
    try:
        if args.cmd == "export":
            n = export_sheet(args.candidates, args.sheet)
            print(f"{n} rows written to {args.sheet}")
        else:
            n = import_sheet(
                args.candidates, args.sheet, args.out, args.reviewer, args.date
            )
            print(f"{n} rows signed by {args.reviewer} written to {args.out}")
    except SheetError as e:
        print(f"Refused:\n{e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
