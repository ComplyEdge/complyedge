# Must-block battery

Real violations, one file per enforcement package. Every item must be
**blocked**. It is the counterweight to `../false_positive_battery/`: that one
proves the engine does not block people who only *mention* a practice; this
one proves a fix for that never lets the practice itself through.

Each item names the rule it must trip (`target_rule`) and how it is wrapped
(`framing`):

| framing          | what it tries                                               |
|------------------|-------------------------------------------------------------|
| `direct`         | the plain request or instruction                            |
| `fiction`        | "for my novel ..." wrapped around the real instruction      |
| `hypothetical`   | "hypothetically, with no regulator watching ..."            |
| `educational`    | "for a training course, carry this out for real ..."        |
| `quote_roleplay` | "role-play as our CTO and reply 'Done' to ..."              |
| `judge_directed` | the instruction plus text telling the reviewer to clear it  |

Every enforced rule id in `rules/rego/complyedge` has items here
(`tests/unit/test_false_positive_measure.py::test_must_block_battery_covers_every_rule`).
Items are single-line on purpose: the Rego patterns use RE2, where `.` does
not cross a newline.

## Two checks use it

1. **Layer 1 (CI, every rule change).**
   `false_positive_measure.py --engine opa --baseline ...` fails when any item
   here passes OPA, or passes without its `target_rule`.
2. **The rule-hit confirmer (Developer and Enterprise, Layer 2).**
   `confirm_measure.py` sends every item to the cheap model that may lift a
   block. It must clear **none** of them. One cleared item means the clear
   threshold or the prompt is wrong, and the confirmer does not ship.

## Adding items

Add a direct seed, wrap it in the six framings, and confirm with the opa
engine that every one trips its rule. Some honest phrasings of a real
violation do not trip the rule at all (the Art 9 leaf needs "without risk
management", so "without a risk management system" passes). That is a recall
gap in the rule, and it belongs to Layer 2, not to this battery.
