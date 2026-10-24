# ComplyEdge: EU AI Act Article 5(1)(f) exception + Article 50(3): Permitted-Context Notice
#
# Emotion recognition in workplace/education is prohibited under Article 5(1)(f)
# except for medical or safety reasons. Even in those permitted contexts,
# Article 50(3) still requires deployers to inform natural persons exposed to
# the system. Deploying medical/safety emotion recognition without notice is a
# transparency failure.
#
# Layer 1 detects: within one line and in this order, medical or safety, then
# "emotion recognition" or "emotion infer", then the whole word without, no
# or lack (any ending), never "not", then notice, notif, inform or disclosure;
# "emotion recognition", then medical or safety, then the same words, then
# notice, notif, inform or disclosure; and deploy or use, then "emotion
# recognition", then medical or safety, then "without informing" or "no
# notice". It matches wording, not meaning: it misses "do not inform" and the
# practice told in other words, it fires on text that only names
# it, and it fires even where the Article 50(3) exception for systems
# permitted by law to investigate criminal offences applies ("As permitted by
# national law to investigate the offence, police use emotion recognition for
# safety screening at the border without notice to the suspect."). Whether a
# text deploys the system without informing the people exposed, and whether
# the exception applies, is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(3)
# Recital: 132: natural persons should be notified when they are exposed to AI systems that, by processing their biometric data, can identify or infer their emotions or intentions; 44: limits of emotion recognition
# Effective: 2026-08-02
# Penalty: up to EUR 15M or 3% of total worldwide annual turnover, whichever is higher (Article 99(4), point (g))
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_50/par_3/oj
# Provision: Regulation (EU) 2024/1689, Article 50(3)

package complyedge.article50.emotion_permitted_context_notice

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:medical|safety).*(?:emotion\\s+recognition|emotion\\s+infer).*\\b(?:without|no|lack\\w*)\\b.*(?:notice|notif|inform|disclosure)",
		"emotion\\s+recognition.*(?:medical|safety).*\\b(?:without|no|lack\\w*)\\b.*(?:notice|notif|inform|disclosure)",
		"(?:deploy|use).*emotion\\s+recognition.*(?:for\\s+)?(?:medical|safety).*(?:without\\s+informing|no\\s+notice)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-3-002"

citation := "Regulation (EU) 2024/1689, Article 50(3): Deployers of an emotion recognition system or a biometric categorisation system shall inform the natural persons exposed thereto of the operation of the system, and shall process the personal data in accordance with Regulations (EU) 2016/679 and (EU) 2018/1725 and Directive (EU) 2016/680, as applicable. This obligation shall not apply to AI systems used for biometric categorisation and emotion recognition, which are permitted by law to detect, prevent or investigate criminal offences, subject to appropriate safeguards for the rights and freedoms of third parties, and in accordance with Union law."
severity := "high"

remediation := "If emotion recognition is deployed for a lawful medical or safety purpose, inform exposed natural persons of its operation per Article 50(3). Document the permitted-context basis."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
