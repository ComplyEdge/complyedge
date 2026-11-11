#!/usr/bin/env python3
"""Render demo_record.json as the coloured JSON the homepage log modal shows.

The homepage modal must be the exported record, unedited. This prints the
<code> body from demo_record.json so nobody types it by hand:
    python render_log_html.py > /tmp/log.html
"""
import html
import json
import sys
from pathlib import Path

KEY = "<span class='text-primary'>{}</span>"
STR = '<span class="text-emerald-300">{}</span>'
LIT = '<span class="text-amber-300">{}</span>'


def scalar(v) -> str:
    if isinstance(v, str):
        return STR.format(html.escape(json.dumps(v, ensure_ascii=False), quote=False))
    return LIT.format(json.dumps(v))


def render(v, indent: int = 0) -> str:
    pad = "  " * indent
    if isinstance(v, dict):
        if not v:
            return "{}"
        rows = [f'{pad}  "{KEY.format(k)}": {render(x, indent + 1)}' for k, x in v.items()]
        return "{\n" + ",\n".join(rows) + f"\n{pad}}}"
    if isinstance(v, list):
        if not v:
            return "[]"
        if all(not isinstance(x, (dict, list)) for x in v):
            return "[" + ", ".join(scalar(x) for x in v) + "]"
        rows = [f"{pad}  {render(x, indent + 1)}" for x in v]
        return "[\n" + ",\n".join(rows) + f"\n{pad}]"
    return scalar(v)


if __name__ == "__main__":
    record = json.loads(Path(__file__).with_name("demo_record.json").read_text())
    sys.stdout.write(render(record))
