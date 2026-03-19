# LAB4 成果物チェックリスト

## 出力ファイル-terrafrom_startup.sh に組み込まれています
```bash
(d) 東京&テラフォーム出力-json >./lab4-成果物/Tokyo-outputs.json)
(d グローバル & テラフォーム出力-json >./lab4-成果物/global-outputs.json)
(cd newyork_gcp & terraform output-json >../lab4-deliverables/newyork-GCP-Outputs.json)
(cd サンパウロ & テラフォーム出力-json >../lab4-成果物/Saapaulo-outputs.json)
```

# VPN 接続とトンネル状態を一覧表示
```bash
aws ec2 describe-vpn-connections--region ap-northeast-1--query「VPNConnections [*]。{id: VPN 接続 ID、状態:状態、トンネル:VGW テレメトリ}」
```
```バッシュ
[
 {
 「Id」:「vpn-0e477dca4384bf6c3"、
 「状態」:「利用可能」,
 「トンネル」: [
 {
 「許可されたルート数」: 2、
 「最終ステータス変更」:「2026-03-07T 23:01:00 + 00:00」,
 「外部IPアドレス」:「35.72.94.63"、
 「ステータス」:「稼働中」,
 「ステータスメッセージ」:「2 つの BGP ルート」
 },
 {
 「許可されたルート数」: 2、
 「最終ステータス変更」:「2026-03-07T 22:59:51 + 00:00」,
 「外部IPアドレス」:「57.180.229.172"、
 「ステータス」:「稼働中」,
 「ステータスメッセージ」:「2 つの BGP ルート」
 }
 ]
 },
 {
 「ID」:「vpn-096019f59b69613fb」,
 「状態」:「利用可能」,
 「トンネル」: [
 {
 「許可されたルート数」: 2、
 「最終ステータス変更」:「2026-03-07T 23:00:00 + 00:00」,
 「外部IPアドレス」:「13.193.98.4"、
 「ステータス」:「稼働中」,
 「ステータスメッセージ」:「2 つの BGP ルート」
 },
 {
 「許可されたルート数」: 2、
 「最終ステータス変更」:「2026-03-07T 23:00:12 + 00:00」,
 「外部IPアドレス」:「35.74.163.246"、
 「ステータス」:「稼働中」,
 「ステータスメッセージ」:「2 つの BGP ルート」
 }
 ]
 }
]
```



GCP アウトプット:
```bash
 {
 「gcp_ha_vpn_interface_0_ip」: {
 「センシティブ」: false、
 「タイプ」:「文字列」,
 「値」:「34.183.45.1"
 },
 「gcp_ha_vpn_interface_1_ip」: {
 「センシティブ」: false、
 「タイプ」:「文字列」,
 「値」:「34.184.42.221"
 },
 「日本町_ilb_ip」: {
 「センシティブ」: false、
 「タイプ」:「文字列」,
 「値」:「10.235.1.4"
 }
```

### トランジットゲートウェイヘルスチェック
**TGW: サンパウロ**
![TGW サンパウロヘルスチェックの画像。](/LAB4-DELIVERABLES/images/tg-healthcheck-saopaulo.PNG「TGW サンパウロヘルス」)
#
**TGW: 東京**
![TGW 東京ヘルスチェックの画像。](/LAB4-DELIVERABLES/images/tg-healthcheck-tokyo.PNG「TGW 東京ヘルス」)

#

#### RDS メモ:
![内部ロードバランサーのイメージ。](/LAB4-DELIVERABLES/images/lab4-db-notes.PNG「RDS Notes」)

## 成果物 1-プライベート専用アクセス証明
-[X] ILB の内部詳細のキャプチャ:
```bash
gcloud コンピューティング転送ルールには、日本町-fr01--リージョン us-central1 が記載されています
```


#### 出力:
```バッシュ
IP アドレス:10.235.1.4
IP プロトコル:TCP
作成タイムスタンプ:'2026-03-07T 14:59:24.156-08:00 '
説明:」
フィンガープリント:JGXWU2-6S0i=
ID: '269262957534319395'
種類:コンピューティング #forwardingRule
ラベルフィンガープリント:42 WM SPB 8 RSM =
負荷分散スキーム:内部_マネージド
名前:日本町-fr01
ネットワーク:https://www.googleapis.com/compute/v1/projects/taaops/global/networks/nihonmachi-vpc01
ネットワーク階層:プレミアム
ポートレンジ:443-443
リージョン:https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1
セルフリンク:https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1/forwardingRules/nihonmachi-fr01
ID: https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1/forwardingRules/269262957534319395 の付いたセルフリンク
サブネットワーク:https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1/subnetworks/nihonmachi-subnet01
ターゲット:https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1/targetHttpsProxies/nihonmachi-httpsproxy01
```


インスタンスリスト:
```bash
gcloud コンピュートインスタンスリスト--filter= "名前~日本町アプリ」

名前:日本町アプリ-r65k
ゾーン:US-セントラル1-b
マシンタイプ:E2-ミディアム
プリエンプティブル: 
内部IP: 10.235.1.3
外部IP: 
ステータス:実行中

名前:日本町アプリ-5x6l
ゾーン:US-セントラル1-F
マシンタイプ:E2-ミディアム
プリエンプティブル: 
内部IP: 10.235.1.2
外部IP: 
ステータス:実行中
```

バックエンドヘルス:
``バッシュ
gcloud compute バックエンドサービス get-health 日本町-backend01--region us-central1

ステータス:
 ヘルスステータス:
 -健康状態:健康
 インスタンス:https://www.googleapis.com/compute/v1/projects/taaops/zones/us-central1-b/instances/nihonmachi-app-r65k
 IP アドレス:10.235.1.3
 ポート:443
 -ヘルスステート:ヘルシー
 インスタンス:https://www.googleapis.com/compute/v1/projects/taaops/zones/us-central1-f/instances/nihonmachi-app-5x6l
 IP アドレス:10.235.1.2
 ポート:443
 種類:コンピューティング #backendServiceGroupHealth
```

-[X] VPN コリドー内のホストから、内部 ILB アクセスを確認します。

#### トンネル 1: 内部IP: 10.235.1.3
テストコマンド-これを使って接続してください:
```bash
gcloud compute ssh nihonmachi-app-r65k--zone=us-central1-f--project=taaops--zone us-central1-b--project=taaops--tunnel-through-iap--ssh-key-file ~/.ssh/taaops_gcp
```



```バッシュ
 curl-k https://10.235.1.3/health
オーケー
```

```バッシュ
jastek_sweeney @nihonmachi-app-r65k: ~$ curl-k https://10.235.1.3/
<h1>日本町クリニック (私立)</h1>
<p>VPN コリドー経由でのみアクセス可能。</p>
```
#
#### 画像: 
***アプリインスタンス***
![アプリケーションインスタンスのイメージ。](/LAB4-DELIVERABLES/images/appInstances.PNG「アプリケーションインスタンス」)

***トンネル 1: ***
![内部ロードバランサーの画像。](/LAB4-DELIVERABLES/images/ILBaccess-tunnel1-test2.PNG「トンネル 1」)

***トンネル 2: ***
![内部ロードバランサーの画像。](/LAB4-DELIVERABLES/images/ILBaccess-tunnel2-test2.PNG「トンネル 2」)


***出力:***
```バッシュ
curl-k https://10.235.1.3/health
最終ログイン:2026 年 3 月 5 日 (木) 08:53:36 35.235.245.129 から
jastek_sweeney @nihonmachi-app-fz32: ~$ curl-k https://10.235.1.3/health
わかった


curl-k https://10.235.1.3/
jastek_sweeney @nihonmachi-app-fz32: ~$ curl-k https://10.235.1.3/
<h1>日本町クリニック (私立)</h1>
<p>VPN コリドー経由でのみアクセス可能。</p>
```

#### トンネル 2: 内部IP: 10.235.1.2


***テスト:***
```バッシュ
curl-k https://10.235.1.2/health
オーケー

curl-k https://10.235.1.2/
<h1>日本町クリニック (私立)</h1>
<p>VPN コリドー経由でのみアクセス可能。</p>
```

#
-[X] パブリックインターネットから、内部 ILB が応答しないことを示してください。
```bash

curl-k https://10.235.1.3/health
curl: (28) 21052 ミリ秒後に 10.235.1.3 ポート 443 に接続できませんでした:サーバーに接続できませんでした

ジョン・スウィーニー @SEBEK MINGW64 ~/AWS/Class7/Armageddon/Jastekai/SEIR_FOUNDATIONS/LAB4 (メイン)
$ curl-k https://10.235.1.2/health
curl: (28) 21045 ミリ秒後に 10.235.1.2 ポート 443 に接続できませんでした:サーバーに接続できませんでした
```
***結果:公開テスト-ILB が応答しません:***
![公開テスト画像。](/LAB4-DELIVERABLES/images/ILB-publictest-test2.PNG「パブリックテスト。」)

## 成果物 2-MIG プルーフ
-[X] マネージドインスタンスグループのリスト:
```bash
gcloud コンピュートインスタンスグループ管理リスト-リージョン us-central1
```

#### 画像:
***ミグテスト:***
![ミグの画像。](/LAB4-DELIVERABLES/images/MIGs.PNG「MigS。」)

***出力:***
```バッシュ
名前:日本町ミグ01
所在地:米国中部1
スコープ:リージョン
ベースインスタンス名:日本町アプリ
サイズ:2
ターゲットサイズ:2
インスタンス_テンプレート:日本町-tpl01-20260307225735043200000001
オートスケーリング:いいえ
```

-[X] アプリインスタンスを一覧表示:
```bash
gcloud コンピュートインスタンスリスト--filter= "名前~日本町アプリ」
```

出力:
```バッシュ
名前:日本町アプリ-r65k
ゾーン:US-セントラル1-b
マシンタイプ:E2-ミディアム
プリエンプティブル: 
内部IP: 10.235.1.3
外部IP: 
ステータス:実行中

名前:日本町アプリ-5x6l
ゾーン:US-セントラル1-F
マシンタイプ:E2-ミディアム
プリエンプティブル: 
内部IP: 10.235.1.2
外部IP: 
ステータス:実行中
```

## 成果物 3-東京 RDS 接続証明

テストスクリプト (`/usr/local/bin/rds_test.py`) と環境プロファイル (`/etc/profile.d/tokyo_rds.sh`) は、起動時に GCP VM 起動スクリプトによってインストールされます。

**ステップ 1 — IAP を使用して実行中の VM の 1 つに SSH 接続します。**
```bash
gcloud compute ssh nihonmachi-app-r65k--zone=us-central1-b--project=taaops--tunnel-through-iap--ssh-key-file ~/.ssh/taaops_gcp
```

**ステップ 2 — VM でプロファイルを取得し、環境変数を確認します。**
```bash
# 起動スクリプトが書いたもの (RDS ホスト、ポート、ユーザ、パスワード、DB) をロードする
ソース /etc/profile.d/tokyo_rds.sh

# セーフティネット:GCP シークレットが存在する前にプロファイルが書き込まれた場合は、パスワードを再取得する
[-z「$TOKYO_RDS_PASS」] && export TOKYO_RDS_PASS=$ (gcloud シークレットのバージョンは最新版にアクセス可能--secret=日本町-東京-RDS-パスワード)

エコー「ホスト:$TOKYO_RDS_HOST」
echo「ユーザー:$TOKYO_RDS_USER」
echo「データベース:$TOKYO_RDS_DB」
echo「パス:$ {#TOKYO_RDS_PASS} 文字」
```

期待値 (現在の VM の起動スクリプトですべて正しく設定されている):
-`ホスト`: `taaops-aurora-cluster-02.cluster-cziy8u28egkv.ap-northeast-1.rds.amazonaws.com`
-`ユーザー`: `管理者`
-`DB`: `ギャラクタス`
-`Pass`: ゼロ以外の文字カウント


出力:
```バッシュ
ホスト:taaops-aurora-cluster-02.cluster-cziy8u28egkv.ap-northeast-1.rds.amazonaws.com
ユーザー:管理者
DB: ギャラクタス
パス:10 文字
```


**ステップ 3 — 接続テストを実行する:**
```bash
python3 /usr/local/bin/rds_test.py
```

期待される JSON 出力は以下のとおりです。
```json
{
 「ステータス」:「OK」,
 「最新_TS」:「2026-03-05T...」
}
```

-[X] JSON アウトプットをサブミットします。

**実際の出力 (IAP トンネル経由で 2026-03-08 でキャプチャ + 日本町アプリ-r65k からのリンク): **
```json
{
 「ステータス」:「OK」,
 「latest_ts」:「2026-03-08T 11:56:24.921 289"
}
```
#
## 制限リマインダー
-[X] GCP にデータベースがありません
-[X] ログに PHI がありません
-[X] VPN コリドー経由のプライベートアクセスのみ
-[X] パスワード/シークレットは TF または Git にハードコーディングしてはいけません

## 成果物 4-プロセス証明 (PSK 規律リマインダー)

### PSK 規律 — プロセスとコンプライアンスに関する注記

1.**生成**: 4 つの VPN PSK (トンネル 1 —トンネル 4) はすべて `openssl rand-base64 48` (64 文字のランダム文字列) で生成されました。辞書に載っている単語も、トンネルをまたいで値が繰り返されることもありません。

2.**配布 (帯域外) **: PSK は別の安全なチャネル (暗号化されたパスワードマネージャー/1Password vault 共有) を介してのみ送信されました。メールで送信されたり、Slackされたり、Gitリポジトリにコミットされたりすることはありませんでした。

3.**テラフォームストレージ**: PSKは、適用時にシェルに設定された `tf_var_PSK_Tunnel_*` 環境変数を介してテラフォームに渡されます。`terraform.tfvars` ファイルにはシークレットでない値のみが含まれており、コミットしても安全です。`.tfvars` ファイルのコメントは、そこに PSK をハードコーディングしないよう明示的に警告しています。

4.**ステートファイルリスク**: Terraform ステートファイルは S3 リモートバックエンドに保存されます。VPN PSK は Terraform 変数として提供されるため、状態には機密値が存在する可能性があります。各バックエンドは S3 サーバー側の暗号化 encrypt = true、S3 ネイティブステートロック use_lockfile = true に設定されています。ステートオブジェクトへのアクセスは、IAM とバケットポリシーによって Terraform ロールと権限のあるオペレーターのみに制限し、パブリックアクセスは禁止する必要があります。バケットに設定されている場合は、リカバリと監査をサポートするためにバージョニングを有効にする必要があります。
5。**ポリシーに違反する可能性のあるコンプライアンス上の誤り**:
 -Git にコミットされた「.tf」ファイルまたは「.tfvars」に PSK をハードコーディングすると、シークレット衛生と SOC 2/HIPAA シークレット管理コントロールに違反します。
 -VPN トンネルネゴシエーションの詳細 (IKE フェーズ 1/2 出力) を制限なく CloudWatch に記録する — ログストリームで PSK が公開されるリスクがある。
 -CloudFront アクセスログ、ALB ログ、または VPC フローログへの PHI の書き込み — フローログは IP/ポートのメタデータのみをキャプチャしますが、ALB ログ内のフィールドレベルの PHI (クエリ文字列など) は、トラフィックが VPN コリドーを経由していても HIPAA 違反となります。
 -PHI をローカルの GCP データベースまたは暗号化されていないデータストアに保存することは、HIPAA の保存時暗号化要件に違反します。

6.**ローテーション規律**: PSKローテーションには、調整された2段階の更新が必要です。
 1. まず、AWS VPN トンネル設定と GCP VPN トンネル設定の PSK をアトミックに更新します。
 2. 次に `tf_var_PSK_Tunnel_*` を更新し、`terraform apply` を再実行して状態を同期してください。

 ローテーションはスケジュールどおりに (1 年以上) 行うか、セキュリティ侵害が疑われる場合は直ちに行う必要があります。

#

## ブレークグラス CloudFront キャッシュ無効化

緊急時 (デプロイ不良、キャッシュポイズニング、古いコンテンツ) で CloudFront キャッシュをクリアします。2 つのオプション:

### オプション 1 — シェルスクリプト (最速、Terraform ステートは不要)

リモートステートまたは `lab4-deliverables/global-outputs.json` からディストリビューション ID を自動的に読み取り、AWS API を直接呼び出します。

```bash
# LAB4 ルートから — すべてを無効にする
bash scripts/order66.sh

# ターゲットパス
bash scripts/order66.sh「/images/*」「/api/*」"/index.html」
```

スクリプトは以下を呼び出す前に確認を求めます。
```bash
AWS クラウドフロント作成無効化\
 <DIST_ID>--ディストリビューション ID\
 <ts>--invalidation-batch '{「パス」: {「数量」: N,「アイテム」: [...]},「呼び出し元参照」:「break-glass-"}'
```

### オプション 2 — Terraform アクションブロック (「グローバル」適用に関連付けられ、オーディットトレイルを作成する)

```bash
CD グローバル
テラフォーム適用-var='break_glass_paths= [」/* "] '
# または特定のパス:
terraform apply-var='break_glass_paths= [」/images/*」,」/index.html「] '
```

>**このスクリプトがブレークグラスに適している理由:** 数秒で起動します。Terraform にはプラン/適用サイクルとクリーンステートロックが必要です。Terraform アクションは、無効化をデプロイパイプラインに記録したい場合に使用します。

### order66.sh のテスト

**ステップ 1 — ターゲットパスで実行** (同じコードパスの `/*` より安い):
```bash
# LAB4 ルートから
ソース:.secrets.env
bash scripts/order66.sh "/static/placeholder.png」
# プロンプトで 'yes' と入力します。
# 出力:無効化 ID とステータスが InProgress のテーブルです。
```

**ステップ 2 — 無効化が完了したことを確認する:**
```bash
AWS クラウドフロントリストの無効化\
 --distribution-id $ (cd グローバル & テラフォーム出力-raw cloudfront_distribution_id)\
 --query「無効化リスト.アイテム [0]。{Id: Id、ステータス:ステータス、作成時間:CreateTime}」\
 --テーブルを出力する
# 30 ～ 60 秒以内にステータスが [進行中] → [完了] から切り替わるはずです。
```

**ステップ 3 — キャッシュが破壊されたことを確認する:**

テスト:
テストは index.html ではなく静止画像に対して実行されました。ユーザーデータ内には、イメージには「キャッシュテスト用」と特別に指定された安定した mtime (touch-t 202602070000) があります。
![静止画像画像。](/LAB4-DELIVERABLES/images/static-image-def.PNG「スタティックイメージ設定」)


これは決定論的なバイナリアセットであり、キャッシュのヒットとミスは明確です (Content-Lengthとx-cacheを確認してください)。
/index.html は Flask によって動的に生成されるため、キャッシュの動作設定によっては CloudFront がまったくキャッシュしない場合があります (例:Cache-Control による動的応答:キャッシュなしではキャッシュされません)


```bash
CF_DOMAIN=$ (cd グローバル&テラフォーム出力-未加工のクラウドフロント_ディストリビューション_ドメイン名)
curl-Si "https://${CF_DOMAIN}/static/placeholder.png" | grep-i「x-cache\ |age:」
# 無効化後の最初のヒット時に予想される:
# X-Cache: クラウドフロントからのミス ← キャッシュが無効になり、オリジンがヒットしました
# 2 回目のヒットでオブジェクトが再キャッシュされる:
curl-Si "https://${CF_DOMAIN}/static/placeholder.png" | grep-i「x-cache\ |age:」
# X-Cache: クラウドフロントからのリフレッシュヒット ← 正常に再キャッシュされました
```

#### 結果:
***ブレークグラス:***
![割れガラスの画像。](/LAB4-DELIVERABLES/images/order66-header.PNG「ブレークグラス」)

***無効化チェック***
![無効化チェックイメージ。](/LAB4-DELIVERABLES/images/invalidation-check.PNG「インバリデーションチェック」)

#

***概要***
>**検証済み出力 (2026-03-10): ** `IEQGERT8FRJWC8CA3QBIZEMFX6` の無効化が完了しました。「E313MTDIOOC9AQ」で更新ヒットが確認されました。

> >** ⚠️ Git Bash/Windows ゴッチャ — MSYS パス変換:**
>Git Bash は POSIX スタイルのパス (例えば `/static/placeholder.png`) を自動的に Windows パスに変換します
>(`aws.exe` のようなネイティブ Windows バイナリに渡す前に `C: /Program Files/Git/static/PNG` など)。
>これにより、そのパスが有効な無効化パスではなくなったため、CloudFront から「InvalidArgument」エラーが発生します。
>>**修正:** `order66.sh` はスクリプトの先頭に `MSYS_NO_PATHCONV=1` と `MSYS2_ARG_CONV_EXCL= "*" `を次のように設定します
> >この変換をグローバルに無効にする。 
**CloudFront パス (または同様のパス) を渡すその他のスクリプトまたはワンライナー
>Git Bash から AWS CLI への URL 形式の `/` パス) も同じように** するか、コマンドの前にエクスポートのプレフィックスを付ける必要があります。
>```バッシュ
>MSYS_NO_PATHCONV=1 AWS クラウドフロント作成/無効化--パス「/static/*」
>```

---


## その他の機能
-[X] ログの英語から日本語への翻訳

次のコマンドを実行して変換を開始します。
```bash
/c/Python311/python.exe python/translate_batch_audit.py--input-bucket taops-translate-input--output-bucket taops-translate-output--source-dir LAB4-DELIVERABLES--glob「*.json」--key-prefix lab4-deliverables--region ap-northeast-1
```

翻訳の説明:

フロー:Lab4-Deliverabes/*.json をすべて検索する→ それぞれを S3 入力バケットにアップロードする → Lambda が翻訳する → 出力バケットをポーリングする →-jpn サフィックスファイルとしてローカライズ版にダウンロードする 

コマンド | 説明
/c/Python311/python.exe | Windows 上の Python 3.11 実行ファイルへのフルパス (C: ドライブは /c/ にマップされています)
translate_batch_audit.py | バッチ変換ドライバースクリプト — 複数のファイルを処理し、ファイルごとに translate_via_s3.py にデリゲートします
--input-bucket taaops-translate-input | Lambda が処理できるようにファイルがアップロードされる S3 バケット
--output-bucket taops-translate-output | Lambda が翻訳された結果を格納する S3 バケット
--source-dir ラボ4-DELIVERABLES | 翻訳するソースファイルを含むローカルディレクトリ
--glob「*.json」| ファイルパターン — LAB4-DELIVERABLES のすべての.json ファイルと一致
--key-prefix lab4-deliverables | S3 キーパスプレフィックス — アップロードされたファイルは s3://taaops-translate-input/lab4-deliverables/ *
--region ap-northeast-1 | 翻訳ラムダと S3 バケットが置かれている AWS リージョン (東京)

#
## 標準クリーンアップコマンド:

S3 バケット-ステートバケット:

>** `terraform_destroy .sh` がステートバケットを削除しない理由:**
>ステートバケット (`taaops-terraform-state-saopaulo`、`taaops-terraform-state-tokyo`) は**ブートストラップリソース**です。`backend.tf`では設定パラメータとしてのみ参照され、どのスタックでも「リソース「aws_s3_bucket」ブロックとして宣言されていません。Terraformは、追跡している状態のリソースのみを破棄します。さらに、Terraform は操作の途中からアクティブに状態を読み取っているバケットを削除することはできません。以下の手動クリーンアップは、破棄が完了した**後に実行する必要があります。

バージョニングが有効な場合-バケットを削除する前にすべてのバージョンを削除し、マーカーを削除します。
```bash
# 1。すべてのオブジェクトバージョンを削除する
aws s3api 削除-オブジェクト\
 --bucket taps-テラフォーム-ステート-サポーロ\
 --リージョン a-イースト 1\
 --delete「$ (aws s3api) リストオブジェクトバージョン\
 --bucket taps-terraform-state-sapaulo\
 --リージョン a-イースト 1\
 --query '{オブジェクト:バージョン []。{キー:キー、バージョン ID: バージョン ID}} '\
 --output json)」2>/dev/null

# 2。すべての削除マーカーを削除する
aws s3api 削除-オブジェクト\
 --bucket taps-テラフォーム-ステート-サポーロ\
 --リージョン a-イースト 1\
 --delete「$ (aws s3api) リストオブジェクトバージョン\
 --bucket taps-terraform-state-sapaulo\
 --リージョン a-イースト 1\
 --query '{オブジェクト:マーカーを削除 []。{キー:キー、バージョン ID: バージョン ID}} '\
 --output json)」2>/dev/null

# 3。残っているオブジェクトを強制的に空にしてバケットを削除する---force は現在のオブジェクトを空にしますが、古いバージョンは削除しません。上記の 3 ステップのバージョンを使用して詳細を確認してください。
aws s3 rb s3://taaops-terraform-state-saopaulo--force--region sa-east-1
```


バージョン管理がオフになっている場合や、バージョンが気にならない場合のショートバージョン:
```bash
aws s3 rb s3://taaops-terraform-state-saopaulo--force--region sa-east-1
```