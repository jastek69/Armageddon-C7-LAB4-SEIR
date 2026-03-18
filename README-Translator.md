# Translation of logs from English to Japanese

Run this command in order to trigger the conversion:
```bash
/c/Python311/python.exe python/translate_batch_audit.py --input-bucket taaops-translate-input --output-bucket taaops-translate-output --source-dir LAB4-DELIVERABLES --glob "*.json" --key-prefix lab4-deliverables --region ap-northeast-1
```

Translation explanation:

Flow: Finds all LAB4-DELIVERABLES/*.json → uploads each to S3 input bucket → Lambda translates → polls output bucket → downloads as -jpn suffix files to localized  

command |	Explanation
/c/Python311/python.exe |	Full path to Python 3.11 executable on Windows (C: drive mapped to /c/)
translate_batch_audit.py |	The batch translation driver script — processes multiple files and delegates to translate_via_s3.py per file
--input-bucket taaops-translate-input |	S3 bucket where files are uploaded for Lambda to process
--output-bucket taaops-translate-output |	S3 bucket where Lambda stores translated results
--source-dir LAB4-DELIVERABLES	| Local directory containing the source files to translate
--glob "*.json"	 | File pattern — match all .json files in LAB4-DELIVERABLES
--key-prefix lab4-deliverables	| S3 key path prefix — uploaded files go to s3://taaops-translate-input/lab4-deliverables/*
--region ap-northeast-1 |	AWS region (Tokyo) where the translation Lambda and S3 buckets are located


Important:
- Structured JSON should be translated with structure-aware mode, not raw document translation.
- Raw document translation can rewrite punctuation/quotes and corrupt JSON syntax.

Recommended patterns:
- For local batch translation, use `python/translate_batch_audit.py --glob "*.json"` (safe JSON mode auto-enables).
- For direct JSON translation, use `python/translate_json_safe.py`.
- S3 bucket-triggered translation Lambda now applies structure-aware JSON translation for `.json` files.
