# LAB4 Python Notes

This folder is a documentation pointer only.

Do **not** copy Python source files into `LAB4-DELIVERABLES/python/`.
The active scripts for LAB4 are maintained in the main repository Python folder:

- [../../python](../../python)

## Purpose

The LAB4 Python work expanded beyond simple helper scripts. The current Python set supports:

- incident triage and evidence collection
- Bedrock-assisted incident report generation
- CloudFront, WAF, TGW, and residency verification checks
- translation pipeline testing and localized deliverable generation

## New or Updated LAB4-Relevant Files

### Core Ops CLI

- [../../python/galactus_cli.py](../../python/galactus_cli.py)  
	Primary LAB4 operations CLI. Consolidates alarm triage, Logs Insights evidence gathering, CloudFront cache probing, origin-cloaking validation, secret/config drift checks, Bedrock report generation, and controlled invalidation actions.

### Incident Response and Bedrock

- [../../python/galactus_alarm_triage.py](../../python/galactus_alarm_triage.py)  
	Lightweight CloudWatch alarm triage utility for fast responder context.

- [../../python/galactus_bedrock_ir_generator_local.py](../../python/galactus_bedrock_ir_generator_local.py)  
	Local Bedrock harness used to test and refine incident report prompts against captured evidence bundles before using the automated workflow.

- [../../python/bedrock_invoke_test_claude.py](../../python/bedrock_invoke_test_claude.py)  
	Simple Bedrock runtime connectivity and model invocation test for Claude access verification.

### Translation Pipeline

- [../../python/translate_batch_audit.py](../../python/translate_batch_audit.py)  
	Batch translation driver. Uploads local deliverable files to the translation input bucket, waits for the S3-triggered Lambda pipeline, and downloads translated outputs into `LAB4-DELIVERABLES/localized/`.

- [../../python/translate_via_s3.py](../../python/translate_via_s3.py)  
	Single-file translation round-trip through the S3 input/output buckets.

- [../../python/translate_json_safe.py](../../python/translate_json_safe.py)  
	Structure-aware JSON translator that preserves valid JSON while translating text values.

### LAB4 Validation and Proof Scripts

- [../../python/galactus_cloudfront_cache_probe.py](../../python/galactus_cloudfront_cache_probe.py)  
	Validates CloudFront caching behavior and response headers.

- [../../python/galactus_cloudfront_log_explainer.py](../../python/galactus_cloudfront_log_explainer.py)  
	Helps interpret CloudFront log behavior for troubleshooting and audit context.

- [../../python/galactus_origin_cloak_tester.py](../../python/galactus_origin_cloak_tester.py)  
	Confirms CloudFront can reach the application while direct origin access is blocked.

- [../../python/galactus_residency_proof.py](../../python/galactus_residency_proof.py)  
	Supports APPI-aligned proof that PHI storage remains in Tokyo.

- [../../python/galactus_tgw_corridor_proof.py](../../python/galactus_tgw_corridor_proof.py)  
	Verifies the intended TGW-based data corridor between compute regions and Tokyo.

- [../../python/galactus_secret_drift_checker.py](../../python/galactus_secret_drift_checker.py)  
	Checks for drift in secrets and related operational configuration.

- [../../python/galactus_waf_summary.py](../../python/galactus_waf_summary.py)  
	Produces WAF-focused operational summaries.

- [../../python/galactus_waf_block_spike_detector.py](../../python/galactus_waf_block_spike_detector.py)  
	Identifies sudden WAF block spikes for security triage.

## Reader Guidance

If you need to:

- run or inspect the scripts, go to [../../python](../../python)
- review localized output artifacts, go to [../localized](../localized)
- review deliverable documentation, go to [../Documentation](../Documentation)

This README is intentionally brief so the deliverables folder stays lightweight and the source of truth remains in the main Python directory.