# JSON Translation Change Log

Date: 2026-03-16

## Summary
Implemented structure-aware JSON translation to prevent invalid JSON output caused by raw document translation.

## Changes

### 1) Batch translator: safe JSON mode and routing
- File: [python/translate_batch_audit.py](python/translate_batch_audit.py)
- Updated defaults and CLI behavior for safer translation:
  - Default glob changed to markdown/text-oriented usage at [python/translate_batch_audit.py](python/translate_batch_audit.py#L35)
  - Added flags:
    - `--allow-structured-json` at [python/translate_batch_audit.py](python/translate_batch_audit.py#L49)
    - `--safe-json` at [python/translate_batch_audit.py](python/translate_batch_audit.py#L57)
    - `--json-translate-keys` at [python/translate_batch_audit.py](python/translate_batch_audit.py#L62)
  - Auto-enable safe mode when using a JSON glob at [python/translate_batch_audit.py](python/translate_batch_audit.py#L72)
  - Added JSON-safe execution path (delegates to safe JSON translator) at [python/translate_batch_audit.py](python/translate_batch_audit.py#L88)
  - Added unsafe-mode warning/skip guidance at [python/translate_batch_audit.py](python/translate_batch_audit.py#L112)

### 2) New structure-aware JSON translator
- File: [python/translate_json_safe.py](python/translate_json_safe.py)
- New script added to preserve JSON validity while translating string fields:
  - CLI and options at [python/translate_json_safe.py](python/translate_json_safe.py#L21)
  - Heuristics to avoid translating machine identifiers at [python/translate_json_safe.py](python/translate_json_safe.py#L40)
  - Recursive JSON translation logic at [python/translate_json_safe.py](python/translate_json_safe.py#L73)
  - Valid JSON output serialization at [python/translate_json_safe.py](python/translate_json_safe.py#L106)

### 3) Bucket-triggered Lambda: JSON-safe path
- File: [modules/translation/lambda/handler.py](modules/translation/lambda/handler.py)
- Updated S3-triggered translation Lambda so `.json` files are translated safely:
  - Added machine-value detection helper at [modules/translation/lambda/handler.py](modules/translation/lambda/handler.py#L22)
  - Added recursive JSON translation helper at [modules/translation/lambda/handler.py](modules/translation/lambda/handler.py#L41)
  - Added JSON detection in main processing path at [modules/translation/lambda/handler.py](modules/translation/lambda/handler.py#L90)
  - Added parse/translate/re-serialize for JSON content at [modules/translation/lambda/handler.py](modules/translation/lambda/handler.py#L95)
  - Set output content type dynamically (`application/json` vs text) at [modules/translation/lambda/handler.py](modules/translation/lambda/handler.py#L116)
  - Updated reports copy function signature/content-type propagation at [modules/translation/lambda/handler.py](modules/translation/lambda/handler.py#L254)

### 4) Operational guidance updated
- File: [LAB4-DELIVERABLES/localized/README.md](LAB4-DELIVERABLES/localized/README.md)
- Updated guidance to reflect current safe JSON support:
  - Safety warning at [LAB4-DELIVERABLES/localized/README.md](LAB4-DELIVERABLES/localized/README.md#L4)
  - Recommended commands at [LAB4-DELIVERABLES/localized/README.md](LAB4-DELIVERABLES/localized/README.md#L8)

## Notes
- Existing corrupted localized JSON artifacts were removed and are intended to be regenerated using safe mode.
- For Lambda behavior to take effect in AWS, redeploy/apply the translation module so updated function code is packaged and published.
