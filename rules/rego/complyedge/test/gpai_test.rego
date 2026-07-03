# ComplyEdge — GPAI Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.gpai_test

import rego.v1

import data.complyedge.gpai.model_classification
import data.complyedge.gpai.copyright_transparency
import data.complyedge.gpai.technical_documentation
import data.complyedge.gpai.systemic_risk
import data.complyedge.gpai.downstream_obligations
import data.complyedge.gpai

# ============================================================
# Model Classification — Article 51
# ============================================================

test_model_classification_blocks_unclassified if {
	model_classification.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy unclassified GPAI model to production without review",
	}
}

test_model_classification_allows_normal_text if {
	not model_classification.violation with input as {
		"jurisdiction": "EU",
		"text": "Our model has been fully classified and registered",
	}
}

# ============================================================
# Copyright Transparency — Article 53(c)
# ============================================================

test_copyright_transparency_blocks_undisclosed_training if {
	copyright_transparency.violation with input as {
		"jurisdiction": "EU",
		"text": "Training data has no copyright disclosure or summary published",
	}
}

test_copyright_transparency_allows_normal_text if {
	not copyright_transparency.violation with input as {
		"jurisdiction": "EU",
		"text": "Full training data summary and copyright policy published",
	}
}

# ============================================================
# Technical Documentation — Article 52
# ============================================================

test_technical_documentation_blocks_undocumented if {
	technical_documentation.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy model with no model card or technical documentation",
	}
}

test_technical_documentation_allows_normal_text if {
	not technical_documentation.violation with input as {
		"jurisdiction": "EU",
		"text": "Comprehensive model card and technical documentation available",
	}
}

# ============================================================
# Systemic Risk — Article 55
# ============================================================

test_systemic_risk_blocks_unassessed if {
	systemic_risk.violation with input as {
		"jurisdiction": "EU",
		"text": "Skip systemic risk assessment for the frontier model launch",
	}
}

test_systemic_risk_allows_normal_text if {
	not systemic_risk.violation with input as {
		"jurisdiction": "EU",
		"text": "Systemic risk assessment completed with full red-teaming",
	}
}

# ============================================================
# Downstream Obligations — Article 53(d)
# ============================================================

test_downstream_obligations_blocks_no_docs if {
	downstream_obligations.violation with input as {
		"jurisdiction": "EU",
		"text": "Provide model to downstream integrators with no documentation or guidance",
	}
}

test_downstream_obligations_allows_normal_text if {
	not downstream_obligations.violation with input as {
		"jurisdiction": "EU",
		"text": "Full integration guide and API documentation provided to all partners",
	}
}

# ============================================================
# Aggregated GPAI tests
# ============================================================

test_aggregated_gpai_detects_violation if {
	gpai.violation with input as {
		"jurisdiction": "EU",
		"text": "Skip systemic risk assessment for the frontier model launch",
	}
}

test_aggregated_gpai_no_violation_for_safe_text if {
	not gpai.violation with input as {
		"jurisdiction": "EU",
		"text": "Standard model serving infrastructure with full compliance documentation",
	}
}
