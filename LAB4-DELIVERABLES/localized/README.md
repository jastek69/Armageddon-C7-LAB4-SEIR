Localized artifacts folder.

Important:
- Structured JSON should be translated with structure-aware mode, not raw document translation.
- Raw document translation can rewrite punctuation/quotes and corrupt JSON syntax.

Recommended patterns:
- For local batch translation, use `python/translate_batch_audit.py --glob "*.json"` (safe JSON mode auto-enables).
- For direct JSON translation, use `python/translate_json_safe.py`.
- S3 bucket-triggered translation Lambda now applies structure-aware JSON translation for `.json` files.
