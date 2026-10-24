# ComplyEdge: text normalisation shared by every rule leaf
#
# Holds no legal condition and no rule_id. Every leaf matches its patterns
# against normalize.text instead of input.text, so the same words decide the
# same way whatever whitespace or quote characters the text happens to use:
#
# - a run of spaces, tabs or Unicode spaces (no-break space U+00A0, U+2000 to
#   U+200A, U+202F, U+205F, U+3000) becomes one space;
# - a line break (CR LF, CR, U+0085, U+2028, U+2029), with the spaces around
#   it, becomes one LF. A line break still ends a line: `.` does not cross it
#   and `^` / `$` with the m flag still see it. `\s` matches it, so a phrase
#   wrapped onto the next line still matches a pattern written with `\s`;
# - curly single quotes become ' and curly double quotes become ".
# - a Unicode hyphen or dash (U+2010 to U+2015: hyphen, non-breaking hyphen,
#   figure dash, en dash, em dash, horizontal bar) becomes "-", so a pattern
#   written with "-" matches a word joined by any of them.
#
# The TrustLint engines (packages/trustlint) apply the same normalisation to
# the YAML rules.

package complyedge.shared.normalize

import rego.v1

_line_space := `[\t\x0B\f \x{A0}\x{1680}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]+`

_line_break := `[\t\x0B\f \x{A0}\x{1680}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]*(?:\r\n|[\n\r\x{85}\x{2028}\x{2029}])[\t\x0B\f \x{A0}\x{1680}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]*`

quotes(s) := regex.replace(regex.replace(s, `[\x{2018}\x{2019}\x{201A}\x{201B}]`, "'"), `[\x{201C}\x{201D}\x{201E}\x{201F}]`, "\"")

hyphens(s) := regex.replace(s, `[\x{2010}-\x{2015}]`, "-")

normalize(s) := regex.replace(regex.replace(hyphens(quotes(s)), _line_break, "\n"), _line_space, " ")

text := normalize(input.text)
