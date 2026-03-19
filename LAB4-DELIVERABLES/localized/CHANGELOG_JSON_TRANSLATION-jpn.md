# JSON トランスレーション変更ログ

日付:2026年3月16日

## まとめ
未加工の文書翻訳による無効な JSON 出力を防ぐために、構造を考慮した JSON 変換を実装しました。

## 変更

### 1) バッチトランスレータ:安全な JSON モードとルーティング
-ファイル:[python/translate_batch_audit.py] (python/translate_batch_audit.py)
-翻訳をより安全にするためにデフォルトと CLI の動作を更新しました。
 -[python/translate_batch_audit.py] (python/translate_batch_audit.py #L35) でデフォルトのグロブがマークダウン/テキスト指向の使用に変更されました
 -フラグの追加:
 -[python/translate_batch_audit.py] の「--allow-structured-json」(python/translate_batch_audit.py #L49)
 -[python/translate_batch_audit.py] の `--safe-json` (python/translate_batch_audit.py #L57)
 -[python/translate_batch_audit.py] の `--json-translate-keys` (python/translate_batch_audit.py #L62)
 -[python/translate_batch_audit.py] で JSON グロブを使用する際にセーフモードを自動的に有効にする (python/translate_batch_audit.py #L72)
 -[python/translate_batch_audit.py] に JSON セーフ実行パス (安全な JSON トランスレータへのデリゲート) を追加しました (python/translate_batch_audit.py #L88)
 -[python/translate_batch_audit.py] (python/translate_batch_audit.py #L112) に非セーフモードの警告/スキップガイダンスを追加しました

### 2) 構造を認識する新しい JSON トランスレーター
-ファイル:[python/translate_json_safe.py] (python/translate_json_safe.py)
-文字列フィールドの翻訳中に JSON の有効性を維持するための新しいスクリプトが追加されました。
 -[python/translate_json_safe.py] の CLI とオプション (python/translate_json_safe.py #L21)
 -[python/translate_json_safe.py] でマシン識別子を変換しないようにするためのヒューリスティック (python/translate_json_safe.py #L40)
 -[python/translate_json_safe.py] (python/translate_json_safe.py #L73) での再帰的な JSON 変換ロジック
 -[python/translate_json_safe.py] での JSON 出力のシリアル化が有効です (python/translate_json_safe.py #L106)

### 3) バケットトリガー型ラムダ:JSON セーフパス
-ファイル:[modules/translation/lambda/handler.py] (modules/translation/lambda/handler.py)
-「.json」ファイルが安全に翻訳されるように S3 でトリガーされる翻訳 Lambda を更新しました。
 -[modules/translation/lambda/handler.py] にマシンバリュー検出ヘルパーを追加しました (modules/translation/lambda/handler.py #L22)
 -[modules/translation/lambda/handler.py] (modules/translation/lambda/handler.py #L41) に再帰的な JSON 翻訳ヘルパーを追加しました
 -[modules/translation/lambda/handler.py] のメイン処理パスに JSON 検出を追加しました (modules/translation/lambda/handler.py #L90)
 -[modules/translation/lambda/handler.py] に JSON コンテンツの解析/変換/再シリアル化を追加しました (modules/translation/lambda/handler.py #L95)
 -[modules/translation/lambda/handler.py] (modules/translation/lambda/handler.py #L116) で出力コンテンツタイプを動的に設定 (「application/json」とテキスト)
 -[modules/translation/lambda/handler.py] で関数のシグネチャ/コンテンツタイプの伝播をコピーするレポートを更新しました (modules/translation/lambda/handler.py #L254)

### 4) 運用ガイダンスを更新しました
-ファイル:[ラボ 4-成果物/ローカライズ/README.md] (ラボ 4-成果物/ローカライズ/README.md)
-現在の安全な JSON サポートを反映するようにガイダンスを更新しました。
 -[lab4-deliverables/LOCALIZED/README.md] での安全に関する警告 (LAB4-deliverables/LOCALIZED/README.md #L4)
 -[lab4-deliverables/LOCALIZED/README.md] で推奨されているコマンド (ラボ4-deliverables/LOCALIZED/README.md #L8)

## メモ
-ローカライズされた既存の壊れた JSON アーティファクトは削除され、セーフモードを使用して再生成される予定です。
-Lambda の動作を AWS で有効にするには、翻訳モジュールを再デプロイ/適用して、更新された関数コードをパッケージ化して公開してください。
