ラボ4 — ジャパンメディカル
トランジットゲートウェイを使用したクロスリージョンアーキテクチャ (APPI 準拠)

この設計は、すべてのPHIがAPPIに準拠するために日本に留まるマルチリージョンの医療アプリケーションです。
 * CloudFront はグローバルアクセスを提供しました
 * サンパウロはステートレスコンピューティングのみを実行しており、すべての読み取り/書き込みはトランジットゲートウェイを経由して東京 RDS に送られます。
 * ニューヨークはステートレスコンピューティングを GCP でのみ実行し、読み取り/書き込みはすべてトンネルローテーションによる HA VPN BGP 接続経由で Tokyo RDS へのトランジットゲートウェイを経由します。
 * この設計では、法的な確実性や監査可能性と引き換えに、ある程度の遅延を意図的に考慮しています。
グローバルアクセスにはグローバルストレージは必要ありません。

🎯 ラボの目的
以下を実現するクロスリージョンの医療アプリケーションアーキテクチャを設計して展開すること。
 2 つの AWS リージョンと 1 つの GCP ゾーンを使用する
 東京 (ap-northeast-1) — データ機関
 サンパウロ (sa-east-1) — コンピュートエクステンション
 AWS トランジットゲートウェイを使用してリージョンを接続します。
 1 つのグローバル URL を介してトラフィックを処理します。
 すべての患者医療データ (PHI) を日本国内にのみ格納
 海外の医師が合法的に記録の読み取り/書き込みが可能


🏥 現実世界の状況（なぜこれが存在するのか）

日本のプライバシー法である個人情報保護法 (APPI) は、個人情報と医療データの取り扱いに厳しい要件を課しています。
医療システムの場合、最も安全で最も一般的な解釈は次のとおりです。
 日本の患者の医療データは日本国内に物理的に保存されなければなりません。(これを台無しにしないでください)

これは以下の場合にも当てはまります。
 患者が海外旅行中
 医者は海外にいます。
 アプリケーションには世界中からアクセスできる

📌 アクセスは許可されています。ストレージは許可されていません。
 --> このラボでは、実際の医療システムがどのようにこのルールに準拠しているかをモデル化します。

🌍 地域的役割
🇯🇵 東京 — 主要地域 (データ機関)
東京は真実の源です。
以下の内容が含まれています。
 RDS (医療記録)
 プライマリ VPC
 アプリケーション層 (ラボ 2 スタック)
 トランジット・ゲートウェイ (ハブ)
 パラメータストアとシークレットマネージャー (権限)
 ロギング、監査、バックアップ
 男性を妊娠させる必要のある本当にホットな女たちだ 

保存中のデータはすべてここにあります。
東京が利用できない場合:
 システムが劣化する可能性があります。
 しかし、データレジデンシーが侵害されることは決してありません

これは意図的で正しいものです。

🇧🇷 サンパウロ — セカンダリーリージョン (コンピューティング専用)

サンパウロは、南米に物理的に存在する医師やスタッフにサービスを提供するために存在しています。

これには以下が含まれます。
 VPC
 EC2 + オートスケーリンググループ
 アプリケーション層 (ラボ 2 スタック)
 トランジット・ゲートウェイ (スポーク)
 放り投げて妊娠させる必要のあるセクシーな女の子も。

以下のものは含まれていません。
 RDSの
 リードレプリカ
 バックアップ
 PHI の永続ストレージ
 ケイシャ。ここにはケイシャはいません。

サンパウロはステートレスコンピューティングです。<----> すべての読み取りと書き込みは東京に直接送られます。


アイオワゾーンは、GCP の利用を希望するニューヨーク在住の医師やスタッフを対象としています。

ニューヨークには以下が含まれます。
 GCP コンピュートリソース:インスタンス、NAT 
 LIB 
 アプリケーション層 (ラボ 2 スタック)
 AWS トランジットゲートウェイへの VPN BGP ピアリング接続
 

次のものは含まれていません。
 RDSの
 リードレプリカ
 バックアップ
 PHI の永続ストレージ
 ケイシャ。ここにはケイシャはいません。

ニューヨークはステートレスコンピューティングです。<----> すべての読み取りと書き込みは東京に直接送られます。

🌐 ネットワークモデル
なぜトランジット・ゲートウェイなのか？
VPC ピアリングの代わりにトランジットゲートウェイが使用されるのは、以下のメリットがあるからです。
 明確で監査可能なトラフィックパス
 一元的なルーティング制御
 エンタープライズグレードのセグメンテーション
 コンプライアンスレビューのための「データ回廊」を可視化

規制の厳しい環境では、利便性よりも明確さが優先されます。

トラフィックの流れ

ドクター (サンパウロ) | (ニューヨーク)
 ↓
クラウドフロント (グローバルエッジ)
 ↓
サンパウロ EC2 (ステートレス) | ニューヨーク EC2 (ステートレス)
 ↓
トランジット・ゲートウェイ (東京)
 ↓
トランジット・ゲートウェイ (サンパウロ)
 ↓
TGW ピアリング
 ↓
トランジット・ゲートウェイ (東京)
 ↓
東京 VPC
 ↓
東京 RDS (PHI はここにのみ保存されています)
パス全体が AWS バックボーンに残り、転送中は暗号化されます。


GCP:

VPC: 日本町-vpc01
│
├── サブネット:日本町-subnet01 (アプリトラフィック — 計算はここで稼働)
│ └── MIG: 日本町-mig01 (日本町アプリ仮想マシン x 2、外部 IP なし)
│
└── サブネット:日本町プロキシ専用サブネット 01 (10.235.254.0/24)
 └── [INTERNAL_MANAGED ILB に必要 — プロキシトラフィックはここを流れ、仮想マシンのトラフィックは流れません]
内部 HTTPS ロードバランサー (内部_マネージド)
├── 転送ルール:日本町-fr01 (IP: 10.235.1.4、ポート 443、日本町サブネット 01 上)
├── ターゲット HTTPS プロキシ:日本町-httpsproxy01
├── URL マップ:日本町-urlmap01
├── バックエンドサービス:日本町-バックエンド01 ──► ミグ日本町-mig01
└── ヘルスチェック:日本町HC01 (HTTPS: 443 /健康)

クラウドルーター (NAT): 日本町ルーター01 /日本町nat01
└── VM のアウトバウンドインターネット (OS の更新など) — VM にパブリック IP はありません

クラウドルーター (BGP): 日本町ルーター ◄ ─── VPN のみ、セパレートルーター
└── ASN: var.nihonmachi_gcp_cloud_router_asn
 └── 広告:var.gcp_advertised_cidr → AWS

HA VPN ゲートウェイ:gcp-to-aws-vpn-gw ► AWS トランジットゲートウェイ
外部 VPN ゲートウェイ:gcp-to-aws-vpn-gw (IP の外部に 4 つの AWS TGW トンネルを保持)
├── トンネル 0 → VPN1 トンネル 1
├── トンネル 1 → VPN 1 トンネル 2
├── トンネル 2 → VPN 2 トンネル 1
└── トンネル 3 → VPN 2 トンネル 2

日本町ミグ01 仮想マシン
 │
 日本町ルーター01 (NAT → インターネット)
 │
 日本町ルーター (BGP) ◄ ──► 4 x VPN トンネル (トンネル 00—03)
 │
 gcp-to-aws-vpn-gw ► AWS TGW
 (HA VPN ゲートウェイ、[AWS からの 4 つの外部 IP アドレスが保存されています。
 2 つの GCP インターフェイス) google_compute_external_vpn_gateway]
 

🌐 単一のグローバル URL

パブリック URL は 1 つだけです:https://jastek.click

クラウドフロント:
 TLS を終了します。
 WAF を適用します。
 ユーザーを最も近い正常な地域にルーティングします。
 患者データは決して保存しません。
 安全と明示的にマークされたコンテンツのみをキャッシュします。

CloudFront が許可されている理由は次のとおりです。
 データベースではありません。
 PHI は永続化されません
 キャッシュ制御ルールを尊重します。

ACM 証明書
-クラウドフロントはパブリック CNAME に us-east-1 の ACM 証明書を使用します。
-東京アルブでは、ap-northeast-1 にある別の ACM 証明書をオリジンホスト名に使用しています。
-GCP 内部 HTTPS ILB は、CAS が発行した証明書をプライベートサービスエンドポイントに使用します。
 -CAS プール:「日本町カスプール」(us-central1)
 -CA: `日本町ルートCA`
 -通称/さん:`nihonmachi.internal.jastek.click`
 -ILB IP: [newyork_gcp/outputs.tf] に `nihonmachi_ilb_ip` を出力します (newyork_gcp/outputs.tf #L9-L12)
 -プライベート DNS: [東京/国道53-私設-ILB.TF] (東京/国道53-私設-ILB.TF #L9-L22) のレコード

Windows 行末の修正 (スクリプトが /usr/bin/env で失敗した場合)
```bash
sed-i 's/\ r$//' terraform_startup.sh terraform_apply.sh
```

# テラフォーム・ビルド・アンド・デストロイ

適用上の注意:

-Git Bash または WSL (スクリプトは bash) を使用してリポジトリルートから実行します。
-バックエンドキーまたはバケットが変更された場合は、まず各スタックフォルダーで「terraform init-reconfigure`」を実行してください。
-東京を適用する前に「TF_VAR_DB_PASSWORD」を設定してください。
-`を使用してください。/terraform_startup.sh `を正しい順序で適用してください (GCP シード-> 東京-> グローバル-> newyork_gcp-> saopaulo)。
-東京州を使用しないニューヨークGCPティアダウンでは、[newyork_gcp/terraform.tfvars] (newyork_gcp/terraform.tfvars) に「enable_aws_gcp_tgw_vpn = false」を設定して、東京のリモートステートルックアップをスキップし、それらの出力に依存するGCP VPNリソースを無効にします。

メモを破棄する:

-`を使用してください。/terraform_destroy.sh `をリポジトリルートから取得します。
-破棄順序は依存関係の影響を受けません。グローバル-> newyork_gcp-> sapaulo-> Tokyo
-スクリプトは確認を促し、リストされているすべてのスタックを破棄します。
-ニューヨークGCPでVPNティアダウンを許可するには、[newyork_gcp/5-gcp-vpn-connections.tf] (newyork_gcp/5-gcp-vpn-connections.tf) のVPNライフサイクルブロックに「prevent_destroy = false」を設定し、その後「true」に戻します。

チェックリストをリセット (クリーンアプライ/破棄)
-破壊する前に、何を保持する必要があるか（Route53パブリックゾーン、ACM証明書）を確認してください。
-すべてのバックエンドキーとリモートステートキーが、下記のリモートステートキーチェックリストの現在のデプロイメントと一致していることを確認します。変更後、各スタックで「terraform init-reconfigure`」を実行します。
-完全に破棄するには、東京の州が見つからない場合は [newyork_gcp/terraform.tfvars] (newyork_gcp/terraform.tfvars) に「enable_aws_gcp_tgw_vpn = false」を設定し、解体中にVPNライフサイクル「prevent_destroy」が「false」に設定されていることを確認します。
-S3 バケットをクリーンに削除する必要がある場合は、破棄中は [Tokyo/Terraform.tfvars] (Tokyo/Terraform.tfvars) に「force_destroy = true」のままにし、破棄後に「false」に復元します。
-`を実行します。リポジトリルートから /terraform_destroy.sh `を実行し、4 つのスタックがすべて完了したことを確認します。状態がないためにスタックに障害が発生した場合は、クリーンアプリケーションの前に残りのリソースを手動で削除してください。
-空の状態からクリーン適用するには、`を実行します。リポジトリルートからの /terraform_startup.sh `(GCP シード-> 東京-> グローバル-> newyork_gcp-> saopaulo)


S3 強制破棄切り替え
-[Tokyo/Terraform.tfvars] (Tokyo/Terraform.tfvars) の「force_destroy」は、S3 バケットにオブジェクトが含まれている場合に S3 バケットを削除できるかどうかを制御します。
-現在の設定:`true` (開発者向け)。本番環境では `false` に設定します。

デストロイ・オーダー ([terraform_destroy.sh] (terraform_destroy.sh) に一致)
1. グローバル
2. ニューヨーク_GCP
3. サンパウロ
4。東京

トンネルローテーションリファレンス
-AWS サイト間 VPN トンネルの変更:https://docs.aws.amazon.com/vpn/latest/s2svpn/modify-vpn-connection.html
-AWS VPN トンネルオプション:https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNTunnels.html
-GCP HA VPN のコンセプト:https://cloud.google.com/network-connectivity/docs/vpn/concepts/ha-vpn
-GCP HA VPN とクラウドルーター:https://cloud.google.com/network-connectivity/docs/router/how-to/creating-ha-vpn
-GCP VPN モニタリング:https://cloud.google.com/network-connectivity/docs/vpn/how-to/monitor-vpn

🏗️ テラフォームと DevOps の構造
重要:マルチテラフォーム・ステート・リアリティ

実際の組織では、1 つの Terraform ステートからリージョンがデプロイされるわけではありません。

このラボでは:
 東京とサンパウロは別々のテラフォーム州です。
 最終的には、各州が別々の Jenkins ジョブに移行することになります。
 各州は以下を通じてのみ通信を行います。
 テラフォーム出力
 リモートステートリファレンス
 明示的変数

これは意図的なものです。---> 実際の DevOps チームがインフラストラクチャを調整する方法を学んでいます。

Terraform リモートステート (ここで実際に使用しているもの)
-東京は TGW ピアリング ID とルートをサンパウロ州から読み取ります。
-サンパウロは TGW/VPC ID と DB エンドポイント/シークレットについて東京州を読み取ります。
-ALB/Route53/WAF オリジン保護のため、グローバルが東京州を読み取ります。

リモートステートキーチェックリスト (新規導入時にはこれらをまとめて更新してください)
| スタック/リファレンス | ファイルと行の範囲 | 設定 |
|--|---|---|---|
| 東京バックエンドキー | [東京/バックエンド.tf] (東京/バックエンド.TF #L6-L12) | `key` |
| グローバルバックエンドキー | [グローバル/バックエンド.tf] (グローバル/バックエンド.tf #L3-L9) | `key` |
| サンパウロバックエンドキー | [saopaulo/backend.tf] (saopaulo/backend.tf #L6-L12) | `key` |
| ニューヨーク GCP バックエンドキー | [newyork_gcp/2-backend.tf] (newyork_gcp/2-backend.tf #L2-L8) | `key` |
| グローバル-> 東京リモートステート | [global/terraform.tfvars] (global/terraform.tfvars #L6-L8) | `tokyo_state_key` |
| サンパウロ-> 東京リモートステート | [saopaulo/terraform.tfvars] (saopaulo/terraform.tfvars #L3-L5) | `tokyo_state_key` |
| ニューヨーク GCP-> 東京リモートステート | [newyork_gcp/terraform.tfvars] (newyork_gcp/terraform.tfvars #L22-L24) | `tokyo_state_key` |
| 東京-> GCP リモートステート | [東京/Terraform.tfvars] (Tokyo/Terraform.tfvars #L63-L66) | `gcp_state_key` |
| 東京-> サンパウロリモートステート | [東京/Main.TF] (東京/Main.TF #L46-L55) | `key` |

オプションアラート
-東京 RDS フローログアラートは、[Tokyo/variables_AWS_GCP_TGW.tf] (Tokyo/Variables_AWS_GCP_TGW.tf) の「enable_rds_flowlog_alarm」によってゲートされます。デフォルトはオフです。

リモートステートはインフラストラクチャ ID と配線に使用されます。
ランタイム設定は、Route53、S3、SSM パラメータストア、シークレットマネージャーなどのマネージドサービスを通じて共有されます。
構成間でデータを共有する代替方法
| システム |... を指定して公開 |... で読む|
|---|---|---|
| DNS (IP アドレスとホスト名) | `aws_route53_record` | 通常の DNS ルックアップ、または「DNS」プロバイダー |
| Amazon S3 | `aws_s3_object` | `aws_s3_object` データソース |
| アマゾン SSM パラメータストア | `aws_ssm_parameter` | `aws_ssm_parameter` データソース |
| Azure Automation | `azurerm_automation_variable_string` | `azurerm_automation_variable_string` データソース |
| Azure DNS (IP アドレスとホスト名) | `azurerm_dns_a_record` (および同様のもの) | 通常の DNS ルックアップ、または「DNS」プロバイダー |
| グーグルクラウド DNS (IP アドレスとホスト名) | `google_dns_record_set` | 通常の DNS ルックアップ、または「DNS」プロバイダー |

リポジトリレイアウト
ラボ 4/
├── 東京/ # プライマリ AWS リージョン (データオーソリティ+ TGW ハブ)
│ ├── メイン.tf
│ ├── tgw-route-tables.tf
│ ├── ベッドロック・オートレポート.tf
│ ├── .tf を出力します
│ └── バックエンド.tf
├── saopaulo/ # セカンダリ AWS リージョン (ステートレスコンピューティング+ TGW スポーク)
│ ├── メイン.tf
│ ├── data.tf # 東京のリモートステートを読み込む
│ ├── .tf を出力します
│ └── バックエンド.tf
├── グローバル/ # クラウドフロント、WAF、Route53、グローバルエッジコントロール
│ ├── クラウドフロント.tf
│ ├── ワッフ.tf
│ ├── ルート 53.tf
│ └── バックエンド.tf
├── newyork_gcp/ # GCP プライベートアプリケーションスタック + HA VPN/BGP から AWS TGW
│ ├── 5-gcp-vpn-connections.tf
│ ├── compute.tf
│ ├── .tf を出力します
│ └── 2-バックエンド.tf
├── モジュール/ # 再利用可能な Terraform モジュール (翻訳、モニタリング、ロギングなど)
├── ラムダ/ # ラムダソース (IR レポート、アラームフック、ローテーションヘルパー)
├── python/ # バリデーション、CLI、自動化スクリプト
└── スクリプト/ # 適用/破棄と操作ヘルパースクリプト

🚆 命名規則 (重要)

建築にローカルで意図的な印象を持たせるには:
東京 (鉄道駅/ハブの命名)
 新宿-*
 渋谷*
 上野*
 秋葉原*

サンパウロ (日本地区)
 リベルダード-*

ニューヨークの GCP デプロイ
 日本町-*

共有プロジェクト/サービスプレフィックス
 タップ-*
 ギャラクタス*

リソース名を見れば、リージョンがすぐにわかるはずです。

🔧 ラボ 2 からの変更点
東京 (拡張ハブ)
 ラボ 2 のアプリケーション/データ基盤を ap-northeast-1 に置いておく
 TGW ハブ、VPN アタッチメント、ルートテーブルセグメンテーションの追加
 IR パイプライン (クラウドウォッチ/SNS/ラムダ/Bedrock/S3) を追加
 S3 によってトリガーされる翻訳 Lambda に翻訳ハンドオフを追加
 PHI データ権限と RDS を東京に置いておく

サンパウロ (スポーク地域)
 リージョン RDS なしでラボ 2 スタイルのステートレスコンピューティングスタックをデプロイ
 TGW が東京に話しかけたときにつなげよう
 東京/GCP CIDR を TGW コリドーを経由するルート
 東京のリモートステートからインフラストラクチャーの依存関係を読み取る

グローバルスタック (エッジ/コントロールプレーン)
 クラウドフロント + WAF + Route53 グローバルエントリポイント
 オリジン保護と一元化されたエッジポリシー制御

ニューヨーク GCP スタック (クロスクラウド拡張)
 内部 HTTPS ILB + MIG を備えたプライベート GCP アプリケーションスタック
 HA VPN+ BGP から AWS TGW (東京) へ
 GCP には永続的な PHI ストレージはありません

🔐 セキュリティモデル (よくお読みください)
 RDS は以下からのインバウンドのみを許可します。
 東京のアプリケーションサブネット
 サンパウロ VPC CIDR (明示的に)
 パブリック DB アクセスなし
 サンパウロにはローカルの PHI ストレージはありません。
 すべてのアクセスはログに記録され、監査可能です。

これは設計によるコンプライアンスであり、ポリシーによるものではありません。

✅ 証明すべきこと (検証)
サンパウロの EC2 インスタンスから:
 東京 RDS に接続できます。
 アプリケーションはレコードを読み書きできます。
 サンパウロにはデータベースがありません。

AWS コンソール/CLI から:
 TGW アタッチメントはどちらのリージョンにも存在します。
 ルートテーブルにはクロスリージョン CIDR が含まれています。
 トラフィックは TGW のみを通過します。

❌ 明示的に許可されていないもの
 東京以外の RDS
 クロスリージョンレプリカ
 Aurora グローバルデータベース
 患者記録のローカルキャッシュ
 クラウドフロントキャッシュ (PHI)
 「アクティブ/アクティブ」データベース

これを行ってしまうと、アーキテクチャはただ単に「間違っている」のではなく、違法なものになってしまいます。

🎓 このラボがあなたのキャリアにとって重要な理由

ほとんどのエンジニアは次のことを学びます。
 「マルチリージョンにする」
 「すべてを複製して」
 「CompTIAを勉強して、ケイシャにお金を渡して」{
このラボでは次のことを学べます。
 法律が建築を形作る方法
 非対称グローバルシステムの設計方法
 セキュリティ、法務、監査担当者にトレードオフを説明する方法
 DevOps がチームや州全体で実際にどのように機能するか
 パスポート・ブラザーになって、夢の女の子と結婚しましょう。

このラボをわかりやすく説明できれば、上級レベルで活動していることになります。

🗣️ インタビュートークトラック (これを覚えておいてください)

 「私は、すべてのPHIがAPPIに準拠するように日本に留まるクロスリージョンの医療システムを設計しました。
 東京がデータベースをホストし、サンパウロがステートレスコンピューティングを実行し、Transit Gatewayが制御されたデータコリドーを提供しました。
 CloudFront は、データレジデンシーを侵害することなく 1 つのグローバル URL を提供してくれました。」

その答えが部屋を止めてしまうでしょう。

🧠 覚えておくべき一文---> グローバルアクセスにはグローバルストレージは必要ありません。
 覚えておくべきもう一つの文---> 私はこのラボを2026年に修了し、2029年に家族ができました。




Aurora におすすめのテラフォームレイアウト

## providers.tf/versions.tf:
AWS プロバイダー、リージョン、デフォルトタグ。

## 変数.tf/locals.tf:
DB エンジン/クラス/バージョン、インスタンス数/AZ、ユーザー名/パスワード (Secrets Manager/SSM を推奨)、バックアップ/保持切り替え、ストレージ暗号化フラグ。
注:`admin_ssh_cidr` は現在セットアップ用にオープンしています (0.0.0.0/0)。本番稼働前にパブリック IP (/32) を厳しくしてください。

## networking-rds.tf:
プライベートサブネットからの DB サブネットグループ。アプリケーション/ECS/EC2 SG からのみ DB ポートを許可する専用 RDS SG。

## vpc-endpoints.tf:
-SSM、EC2 メッセージ、SSM メッセージ、CloudWatch ログ用の VPC エンドポイントをインターフェイスします。
-S3 はゲートウェイエンドポイント (プライベートルートテーブル) を使用します。
-エンドポイントはプライベートサブネットに配置され、エンドポイントセキュリティグループを使用します。
-東京リソース:`aws_vpc_endpoint.ssm`、`aws_vpc_endpoint.ec2messages`、`aws_vpc_endpoint.ssmmessages`、`aws_vpc_endpoint.tokyo_logs`、`aws_vpc_endpoint.s3_gateway`。
-サンパウロリソース:`aws_vpc_endpoint.sao_ssm`、`aws_vpc_endpoint.sao_ec2messages`、`aws_vpc_endpoint.sao_ssmmessages`、`aws_vpc_endpoint.sao_logs`、`aws_vpc_endpoint.sao_ssms`、`aws_vpc_endpoint.sao_ssms` 3_ゲートウェイ`。

# kms.tf:
-RDS ストレージ/ログ、S3 データバケット、シークレットマネージャー用の CMK (「kms: ViaService」経由)。
-CMK「aws_kms_key.rds_s3_data」は RDS ストレージと「jasopsoregon-s3-rds」バケット (SSE-KMS) に使用されます。
-ALB ログバケットはログ配信との互換性のために SSE-S3 (AES256) を使用しています。
-オプション:`kms_key_id` 変数を使用して、後で既存の CMK に切り替えることができます。

## rds-params.tf:
Cluster + インスタンスパラメータグループ、必要に応じてオプショングループ。

## rds-cluster.tf:
aws_rds_cluster (エンジン/バージョン付き)、シークレットまたはマネージドパスワードによる認証情報、バックアップ/削除保護/最終スナップショット設定、ログエクスポート、サブネットグループ、SG、KMS キー、パフォーマンスインサイト。

## rds-instances.tf:
aws_rds_cluster_instance (count/for_each) (インスタンスクラス、AZ 配置、モニタリングロール、パラメーター/オプショングループの参照を含む)。

## シークレット.tf:
シークレットマネージャー/SSM パラメーターと (オプションで) ローテーション。

## シークレットローテーション.tf:
-シークレット・ローテーション Lambda: `SecretsManagerTaaops-Lab1-ASM-Rotation`
-ローテーションスケジュール:テストは 24 時間ごと (本番環境では 30 日に戻す)
-ラムダ VPC 設定:プライベートサブネット + `taaops_lambda_asm_sg`
-注:カスタムローテーション Lambda を使用する場合は、「manage_master_user_password = true」を使用しないでください (サービスマネージドシークレットではカスタム Lambda を使用できません)。
-変数:`secrets_rotation_days` がローテーション間隔を制御します (テストでは `1`、本番環境では `30+` に設定)。

### シークレットマネージャー + ラムダローテーションの処理方法 (Terraform)
この設定では、**カスタム Secrets Manager シークレット** と **ローテーション Lambda** (RDS サービス管理シークレットではない) を使用します。フローは以下のとおりです。

1) `16-secrets.tf` は、初期ユーザー名/パスワード、エンジン、ホスト、ポート、およびデータベース名を使用して `aws_secretsmanager_secret.db_secret` と `db_secret_version` を作成します。
2) `15-database.tf` は、変数から `master_username`/`master_password` を使用して Aurora クラスターを作成します (「manage_master_user_password = true」を使用していないため)。
3) `20-secrets-rotation.tf` は `Lambda/SecretsManagertaaops-lab1-ASM-Rotation.zip `からローテーションラムダをデプロイし、それを VPC にアタッチし、それを呼び出す権限をシークレットマネージャーに付与します。
4) `aws_secretsmanager_secret_rotation` は Lambda を `db_secret` にリンクし、ローテーション間隔 (「secrets_rotation_days`)」を設定します。
5) Lambda は、ローテーションを実行するたびに Aurora の**シークレット**と**DB パスワード** を更新し、同期を保ちます。
キーポイント:
-サービスマネージド型の RDS シークレット (`manage_master_user_password = true`) はカスタムローテーション Lambda を使用できません。
-ローテーションは Lambda の IAM 権限とネットワークアクセス (プライベートサブネット + セキュリティグループ + Secrets Manager エンドポイントまたは NAT) によって異なります。
-テストには「secrets_rotation_days = 1」を使用し、本番環境では「30+」に設定します。

### クラウドウォッチアラーム + SNS 自動化
-クラウドウォッチアラームは「aws_sns_topic.cloudwatch_alarms」にパブリッシュされます。
-オプションのメール通知には「sns_email_endpoint」を使用します（サブスクリプションをスキップする場合は空白のままにします）。
-SNS トピック (ラムダ、SSM オートメーション、PagerDuty など) にオートメーションを添付できます。
-このリポジトリには、基本的な Lambda フックである `aws_lambda_function.alarm_hook` (アラームペイロードをログに記録する) が含まれています。
-アラーム文書 (状態値+アラームメッセージ形式):
```
https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html
https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html#alarm-notification-format
https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html#CloudWatchAlarms
```

### アラームフックパイプライン (SNS → ラムダ → エビデンスバンドル)
CloudWatch アラームが発生すると、アラームフック Lambda は次のステップを実行します。
1) SNS ペイロードのアラームメタデータを解析します。
2) CloudWatch ログインサイトクエリを実行します (`startQuery`/`getQueryResults` 経由)。
3) SSM パラメータストアから設定を取得し、シークレットマネージャーから認証情報メタデータを取得します。
4) Bedrock ランタイムを呼び出して簡単なレポートを生成します (「bedrock_model_id」が設定されている場合)。
5) マークダウン+ JSON エビデンスバンドルを S3 (`alarm_reports_bucket_name`) に書き込みます。
6) SSM オートメーションランブックをトリガーします (「automation_document_name」が空の場合、デフォルトで Terraform で作成されたドキュメントになります)。

関連変数:
-`アラーム_レポート_バケット名`
-`アラーム_ログ_グループ名`
-`アラーム_ログ_インサイト_クエリ`
-`alarm_ssm_param_name`
-`alarm_secret_id` (オプションオーバーライド、デフォルトは Terraform DB シークレット ARN)
-`automation_document_name`
-`オートメーション・パラメータ_json`
-`岩盤_モデル_ID`

### ベッドロック・オート・インシデント・レポート Lambda (23-bedrock_autoreport.tf)
`aws_lambda_function.galactus_ir_lambda01` が使用する環境変数:
-`レポート_バケット`: JSON + マークダウンレポート用の S3 バケット。
-`APP_LOG_GROUP`: アプリケーションログ用の CloudWatch Logs グループ (アプリケーションロググループ名と一致することを確認してください)。
-「WAF_LOG_GROUP`: WAF ログ用のクラウドウォッチロググループ (WAF ロギング → クラウドウォッチの場合のみ)。
-`SECRET_ID`: DB クレッド用のシークレットマネージャーシークレット名/ARN (例:「taaops/rds/mysql」)。
-`SSM_PARAM_PATH`: DB コンフィグのパラメータストアパス (例:`/lab/db/`)。
-`BEDROCK_MODEL_ID`: 岩盤モデル ID (準備ができるまで空白のままにしておきます)。
-`SNS_TOPIC_ARN`:「レポート準備完了」通知の SNS トピック。

レポート出力 (S3 + SNS):
-S3 キーは「レポート/」の下に書かれています。
 <incident_id>-JSON エビデンスバンドル:`reports/ir-.json`
 <incident_id>-マークダウンレポート:`reports/ir-.md`
-SNS メッセージペイロード:
 -`バケット`、`json_key`、`markdown_key`、`incident_id`

AWS ドキュメント (リンク):
```
https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html
https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html
https://docs.aws.amazon.com/lambda/latest/dg/welcome.html
https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html
https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html
https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-documents.html
```

## AWS 翻訳
コード提供:maazinm
https://github.com/maazinmm/AWS-Powered-Text-Translator-App-with-Amazon-Translate.git



### SSM オートメーションドキュメント
[SSM エージェント] (https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-windows.html)
[SSM プラグイン] (https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-console-access.html)
-Terraform はデフォルトのインシデントレポートテンプレートを使用して「aws_ssm_document.alarm_report_runbook」を作成します。
-ラムダは「インシデント ID」、「アラーム名」、および S3 レポートキーをランブックに渡します。

## .tf を出力します。
クラスターとリーダーエンドポイント、SG ID、サブネットグループ名、シークレット ARN。


# IAM
Amazon SSM マネージドインスタンス
クラウドウォッチエージェントサーバーポリシー
taaops-armageddon-lab-policy
 -TODO: これらのマネージド/インラインポリシーがインスタンスロールにアタッチされ、有効であることを確認します。
 -KMS: 書き込み//すべてのリソース// KMS: ViaService = secretsmanager.us-west-2.amazonaws.com
 -シークレットマネージャー//us-west-2 を読む
 -システムマネージャー//us-west-2 の読み取り


# ログと S3 バケット
-RDS データバケット:`jasopsoregon-s3-rds`
-ALB ログバケット:`jasopsoregon-alb-logs`
-ラボアクセスログプレフィックス:`alb/taaops`
<account-id>-ログパス形式:`s3://jasopsoregon-alb-logs/alb/taaops/AWSLogs//...`
-LAB ログ配信ポリシーの範囲は `data.aws_caller_identity.taaops_self01` と `aws_lb.taaops_lb01` です。
-クラウドフロントログバケット:<account-id>`taaops-cloudfront-logs-`
-クラウドフロントログプレフィックス:`cloudfront/`
-推奨:S3 ライフサイクルルールを追加して ALB ログを期限切れまたは移行する (30 ～ 90 日後に期限切れになる、Glacier に移行するなど)。
-推奨:ドキュメントで保持期間の期待値を設定し、パブリックアクセスをブロックしてログバケットを非公開にしておきます。

# WAF ロギング (14b-waf-logging.tf)
-「waf_log_destination」は以下をサポートします。
 -「クラウドウォッチ」(WAF-> クラウドウォッチログ)。ロググループ名は `aws-waf-logs-` で始まる必要があります。
 -`firehose` (WAF-> Kinesis Firehose-> S3)。これを S3 ストレージに使用します (WAF は S3 の直接ロギングをサポートしていません)。
-「waf_log_retention_days` は CloudWatch ログを使用する際のログ保持を制御します。

# Python スクリプト (シェルノート)
Windows 上の Git Bash から Python スクリプトを実行すると、パス変換によって `のような相対パスが壊れる可能性があります。\ python\ script.py` (これは `.pythonscript.py` になります)。代わりに次のいずれかを使用してください。

パワーシェル (推奨):
```
パイソン。\ Python\ script_name.py <args>
```

Git Bash (安全):
```
MSYS2_ARG_CONV_EXCL= "*」Python。/python/script_name.py <args>
```

「ファイルを開くことができません... .pythonscript.py」が表示されたら、PowerShell に切り替えるか、上記の Git Bash コマンドを使用してください。

# ゲートスクリプトの実行 (ラボ 2)
リポジトリルートの Git Bash から:
```
chmod +x python/run_all_gates.sh

ORIGIN_REGION=「$ (テラフォーム出力-未加工のオリジン_リージョン)」\
CF_DISTRIBUTION_ID= "$ (テラフォーム出力-raw クラウドフロント_distribution_id)」\
ドメイン名= "$ (テラフォーム出力-未加工ドメイン名)」\
ROUTE53_ZONE_ID= "$ (テラフォーム出力-raw route53_zone_id)」\
ACM_CERT_ARN= "$ (テラフォーム出力-raw cloudfront_acm_cert_arn)」\
WAF_WEB_ACL_ARN= "$ (テラフォーム出力-raw waf_web_acl_arn)」\
LOG_BUCKET= "$ (テラフォーム出力-未加工のクラウドフロント_ログバケット)」\
ORIGIN_SG_ID= "$ (テラフォーム出力-未加工のオリジン_sg_id)」\
bash。/python/run_all_gates_l2.sh
```

# ゲート警告メモ
-**Origin SG「ソースが見えない」**: ゲートは「IP範囲」、「IPv6範囲」、「ユーザーIDグループペア」をチェックします。**CloudFront マネージドプレフィックスリスト** を使用する場合、SG ソースは「PrefixListIDs」の下にあり、古いチェックでは表示されません。更新されたゲートはプレフィックスリストを読み取り、存在すれば合格するようになりました。

# 適用後の検証チェックリスト
-ALB ターゲットが正常であることを確認します (ELB ターゲットグループのヘルスが「正常」)。
-ALB DNS 上でアプリからの応答を確認する:
 -`GET /` は 200 を返します
 -`GET /init `は DB を初期化し、200 を返します
 -`GET /list `は HTML リストを返します
-シークレットマネージャーシークレットが存在し、ローテーションが有効になっていることを確認します。
-SSM ドキュメント「taaops-incident-report」がアクティブであることを確認します。
-SNS トピック「taaops-cloudwatch-alarms」に Lambda + メールサブスクリプションがあることを確認します。

## クラウドフロント検証 (キャッシュ + 転送)
オリジン TLS に関するメモ:
-CloudFront は専用のオリジンホスト名 (`$ {var.alb_origin_subdomain} など) を使用して ALB に接続します。$ {var.domain_name} `) なので、ALB 証明書が一致します。


### クラウドフロントオリジンクローキング:
注:オリジンのクローキングは、ALB ヘッダールールによってレイヤー 7 で適用されます (SG のみのクローキングではありません)。
REST API (/api/*) よりも HTTPS オリジン+ヘッダー (レイヤー 7) を使用します。
ALB SG はインターネットからのインバウンド 443 を許可します。
ALB HTTPS リスナーには次の機能があります。
 * ルール 1: X-Galactus-Code ヘッダが一致する場合 → 転送 (リスナーヘッダールールでクローキングを強制する)
 * ルール 2: デフォルト/フォールバック → 固定 403
CloudFront オリジンはシークレットヘッダーを送信するので、渡されます。
ダイレクト ALB リクエストにはヘッダーがないため、403 が返されます。
厳密な SG クローキング (CloudFront プレフィックスリストのみ) を強制すると、403 ではなくダイレクト ALB にアクセスできない (タイムアウト/TLS ハンドシェイクが失敗する) ことがあります。

フォローアップチェック (厳密なクローキング防止):
```
nslookup オリジン。<domain>
curl-I https://origin。<domain>
curl-vk https://origin。<domain>
``

# ALB (CloudFront マネージドプレフィックスリスト) へのアクセスを制限する
解説:
-これは SG ルールによる「真のオリジンクローキング」です。CloudFront オリジン側の IP のみが ALB に到達できます。
-ALB への直接トラフィックをネットワーク層でブロックするため、ヘッダーのみのクローキングよりも強力です。
-直接 ALB リクエストがタイムアウトするか、TLS ハンドシェイクが失敗する (HTTP 応答がない) ことが予想されます。
ドキュメント:
```
https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/restrict-access-to-load-balancer.html
https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/LocationsOfEdgeServers.html
https://aws.amazon.com/blogs/networking-and-content-delivery/limit-access-to-your-origins-using-the-aws-managed-prefix-list-for-amazon-cloudfront/
https://docs.aws.amazon.com/whitepapers/latest/aws-best-practices-ddos-resiliency/protecting-your-origin-bp1-bp5.html
```

テスト:
1) 配布ステータスが「デプロイ済み」になっていることを確認する:
```
AWS クラウドフロントリストディストリビューション--query「ディストリビューションリスト.Items [?コメント=='$ {var.project_name}-cf01']。[ID、ステータス、ドメイン名]」--出力テーブル
```

2) 静的キャッシュプルーフ (2 回実行):
```
curl-I https://jastek.click/
curl-I https://jastek.click/
```
期待:
-レスポンスヘッダーポリシーの「キャッシュコントロール:公開、最大年齢=...」
-「Age」が 2 回目のリクエストで表示され増加する
注意:
-静的キャッシュテストでは、インスタンス間でコンテンツが一貫していることを前提としています。「scripts/user_data.sh` では、「/opt/rdsapp/static/index.html」と「/opt/rdsapp/static/example.txt」に固定の mtime を設定して、CloudFront が安定した「ETag」/「最終更新日」を認識できるようにしています。静的コンテンツを意図的に変更した場合は、ファイルの内容を更新し、固定タイムスタンプを更新してください (またはパスを無効にしてください)。

3) API はキャッシュしてはいけません (2 回実行):
```
curl-I https://jastek.click/api/list
curl-I https://jastek.click/api/list
```
期待:
-「年齢」がないか「0」

4) キャッシュキーの健全性 (静的ではクエリ文字列は無視されます):
```
curl-I "https://jastek.click/?v=1」
curl-I "https://jastek.click/?v=2」
```
期待:
-同じキャッシュオブジェクト (経過時間が高いままになるか長くなる)

サニティチェックの実行例:
```
適用後のチェックの実行=true\
target_group_arn= "arn: aws: ElasticLoad Balancing: US-West-2:015195098145: targetgroup/taaops-lb-tg80/39344a5264d40de8"\
alb_dns=「Taaops-Load-Balancer-989477164.us-West-2.elb.amazonaws.com」\
。/sanity_check.sh
```

### 岩盤呼び出しテスト (クロード)
テストスクリプトは環境変数から値を読み取るので、リージョンやモデルをすばやく切り替えることができます。
デフォルト:
-`AWS_REGION`: `us-east-1`
-`BEDROCK_MODEL_ID`: `anthropic.claude-3-haiku-20240307-v 1:0 `
-`BEDROCK_PROMPT`:「ハローワールド」プログラムの目的を一行で説明してください。`

例:
```
AWS リージョン = 米国西部 2\
Bedrock_model_id=「anthropic.claude-3-Haiku-20240307-V 1:0」\
Bedrock_prompt= "こんにちは、一行で言ってください。"\
Python python/bedrock_invoke_test_claude.py
```

### AWS 翻訳パイプラインテスト (S3-> ラムダ-> 翻訳)
翻訳リソース (東京スタックの出力):
-`翻訳_入力_バケット名`: `taaops-translate-input`
-`翻訳_出力_バケット名`: `taaops-translate-output`
-`translation_lambda_function_name`: `taaops-translate-ap-northeast-1-processor`

単一ファイルのエンドツーエンドテスト:
```
パイソン。/python/translate_via_s3.py\
 --入力-バケットタップ-翻訳-入力\
 --output-バケットタップ-翻訳-出力\
 --ソースファイル Tokyo/audit/3b_audit.txt\
 --リージョン AP-ノースイースト-1\
 --LAB3-DELIVERABLES/results/3b_audit_translated_latest.txt にダウンロードしてください
```

すべての監査用テキストファイルのバッチテスト:
```
パイソン。/python/translate_batch_audit.py\
 --入力-バケットタップ-翻訳-入力\
 --output-バケットタップ-翻訳-出力\
 --source-dir 東京/監査\
 --glob「*.txt」\
 --地域 ap-北東-1
```

Lambda 実行ログを検証してください:
```
MSYS2_ARG_CONV_EXCL=「*」は「/aws/lambda/taaops-translate-ap-northeast-1-processor」の末尾をログに記録します\
 —リージョン ap-northeast-1--10 時以降
``

### EC2 (SSM) でリモートチェックを実行する
リモートチェックはインスタンスで実行する必要があります (インスタンスのロールを直接検証します)。ステップ:
1) SSM セッションを開始する:
```
<instance-id>aws ssm スタートセッション--target--リージョン us-west-2
```
2) インスタンスに、次のスクリプトをインストールします。
```
cd /ホーム/ec2-ユーザー
# このリポジトリの sanity_check.sh の内容をファイルに貼り付けます。
cat > sanity_check.sh <<'EOF'
<paste the file contents here>
EOF
chmod +x sanity_check.sh
```
3) リモートチェックの実行:
```
リモートチェックの実行=TRUE。/sanity_check.sh
```

メモ:
-`RUN_REMOTE_CHECKS=TRUE` は EC2 で実行されていない場合は自動的にスキップされます。
-貼り付けるよりもコピーしたい場合は、ローカルターミナル (EC2 セッション内ではなく) から「scp」または「aws ssm send-command」を使用してください。
オプション:貼り付ける代わりに S3 からスクリプトを取得する
1) ローカルターミナルからアップロード:
```
<your-bucket>aws s3 cp sanity_check.sh s3:///tools/sanity_check.sh
```
2) EC2 インスタンス (SSM セッション) で:
```
cd /ホーム/ec2-ユーザー
<your-bucket>AWS S3 cp s3:///tools/sanity_check.sh。/sanity_check.sh
chmod +x。/sanity_check.sh
リモートチェックの実行=TRUE。/sanity_check.sh
```

オプション:署名付き URL を使用する (インスタンスの S3 権限なし)
1) ローカルターミナルから:
```
<your-bucket>aws s3 presign s3:///tools/sanity_check.sh--expires-in 3600
```
2) EC2 インスタンス (SSM セッション) で、curl 経由でダウンロードします。
```
cd /ホーム/ec2-ユーザー
<presigned-url>curl-o sanity_check.sh "」
chmod +x。/sanity_check.sh
リモートチェックの実行=TRUE。/sanity_check.sh
```

### インシデントレポートパイプラインのテスト (手動)
1) テストアラームペイロードの作成:
```
キャット >。/scripts/alarm.json <'EOF'
{
 「アラーム名」:「手動テストアラーム」,
 「アラームの説明」:「インシデントレポートパイプラインを起動するための手動テスト」,
 「新しい状態値」:「アラーム」,
 「古い状態値」:「OK」,
 「ステートチェンジタイム」:「2026-02-01T 12:00:00 Z」,
 「メトリック名」:「RDS アプリエラー」,
 「名前空間」:「Lab/RDS アプリ」,
 「統計」:「合計」,
 「ピリオド」: 60,
 「評価期間」: 1,
 「しきい値」: 1、
 「比較演算子」:「しきい値より大きい、または等しい」
}
EOF
```

2) トリガー SNS トピックにパブリッシュする (Lambda トリガー、再帰を回避):
```
REPORT_TOPIC_ARN= "$ (aws sns list-topics--region us-west-2\)
 --query「トピック [?含む (TopicArn, 'taaops-ir-trigger-topic')] .topicArn」\
 --output text)」

AWS SNS パブリッシュ\
 --topic-arn「$REPORT_TOPIC_ARN」\
 --メッセージファイル://scripts/alarm.json\
 --リージョン (米国西部 2)
```

3) 生成したレポートを S3 に一覧表示する:
```
REPORT_BUCKET= "$ (テラフォーム出力-raw galactus_ir_reports_bucket)」
aws s3 ls "s3://$REPORT_BUCKET/reports/"--region us-west-2
```

4) 最新のマークダウンレポートを見る:
```
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-manual-test-alarm-<timestamp>.md」-
```

オプション:重要なレポートを名前で絞り込む (例ではファイル名に ALARM を含む):
```
aws s3 sync "s3://$REPORT_BUCKET/reports/"。/Reports/IR/\
 --「*」を除外\
 --「*アラーム*.md」を含める\
 --「*Alarm*.json」を含めます\
 --リージョン (米国西部) -2
```

オプションのヘルパースクリプト (ALARM レポートフィルタ/ダウンロード):
```
REPORT_BUCKET= "$ (テラフォーム出力-raw galactus_ir_reports_bucket)」

# アラームレポート JSON ファイルを一覧表示する
REPORT_BUCKET= "$REPORT_BUCKET」/scripts/filter_alarm_reports.sh

# JSON + MD ペアのアラームレポートをダウンロード
REPORT_BUCKET= "$REPORT_BUCKET」/scripts/download_alarm_reports.sh

# アラーム状態フィルタの変更 (「OK」または「データ不足」など)
ALARM_STATE=OK REPORT_BUCKET= "$REPORT_BUCKET」/scripts/filter_alarm_reports.sh
アラーム状態=データ不足レポートバケット=「$レポート_バケット」。/scripts/download_alarm_reports.sh

# その他のフィルター (jq が必要):
# アラーム名と正規表現を一致させる
alarm_name_regex= "Manual-TEST」REPORT_BUCKET= "$REPORT_BUCKET」/scripts/filter_alarm_reports.sh
# Unix エポックタイムスタンプ以降のレポートのみ
ALARM_SINCE_EPOCH=1700000000 REPORT_BUCKET=「$REPORT_BUCKET」/scripts/download_alarm_reports.sh
ALARM_UNTIL_EPOCH=1700003600 REPORT_BUCKET=「$REPORT_BUCKET」。/scripts/download_alarm_reports.sh
<value># 重要度フィルタ (Alarm.Severity を読み取るか、「Severity:" のアラーム説明を解析する)
alarm_SEVERITY=CRITICAL REPORT_BUCKET= "$REPORT_BUCKET」/scripts/filter_alarm_reports.sh
```

シェルノート:
-Git Bash: `を実行してください。/scripts/ *.sh` コマンドは上記のとおりです。
-PowerShell: PowerShell ネイティブのコマンド/サンプル (「Get-ChildItem」、「Select-String」など) を使用してください。

## 自動 IR ランブック (ヒューマン+ Amazon Bedrock インシデントレスポンス)
目的:このランブックでは、人間のオンコールエンジニアが Bedrock で生成されたインシデントレポートを安全に使用し、未加工の証拠と照合して検証し、監査可能な最終的なインシデントアーティファクトを作成する方法を定義しています。

コアルール:Bedrockは分析を加速します。正しさは人間自身のものだ。

### 前提条件
-アラームがトリガーされ、SNS-> Lambda-> S3 パイプラインが完了しました。
-レポートアーティファクトが S3 に存在します (`ir-*.md` + `ir-*.json`)。
-CloudWatch ログ、CloudWatch アラーム、SSM パラメータストア、シークレットマネージャーへのアクセス。

### ステップ 1: レポートとエビデンスバンドルの取得
```
REPORT_BUCKET= "$ (テラフォーム出力-raw galactus_ir_reports_bucket)」
aws s3 ls "s3://$REPORT_BUCKET/reports/"--region us-west-2
<incident_id>aws s3 cp "s3://$REPORT_BUCKET/reports/ir-.md」/reports/IR/IR-report.md
<incident_id>aws s3 cp "s3://$REPORT_BUCKET/reports/ir-.json」。/Reports/IR/IR-Evidence.json
```
### ステップ 2: アラームメタデータの検証 (信頼できる情報源)
-CloudWatch でアラームを開き、以下を確認します。
 -アラーム名、メトリックス、しきい値、評価期間。
 -状態遷移とタイムスタンプ。
```
AWS クラウドウォッチディスクリブアラーム\
 <alarm-name>--アラーム名 ""\
 --リージョン (米国西部 2)\
 --出力テーブル
```

### ステップ 3: ログ証拠の検証 (未処理)
-アプリケーションログ (CloudWatch ログインサイト):
```
AWS ログスタートクエリ\
 --ロググループ名「/aws/ec2/rdapp」\
 <epoch-start>--開始時間\
 --終了時刻<epoch-end>\
 --query-string「fields @timestamp、@message | sort @timestamp desc | リミット 50"\
 --地域 (米国西部 2)
```
-WAF ログ (有効になっている場合、CloudWatch デスティネーション):
```
AWS ログスタートクエリ\
 <project>--ロググループ名「aws-waf-logs--webacl01」\
 <epoch-start>--開始時間\
 --終了時刻<epoch-end>\
 --query-string「fields @timestamp、action、ClientIp として HttpRequest.ClientIP、uri としての HttpRequest.uri | アクション別ヒット数 | stats count () をアクション別ヒット数、ClientIP、uri | ソートヒット説明 | 上限 25"\
 --リージョン us-west-2
```
-レポートの概要が未処理のログ (タイムスタンプ、カウント、キーエラー) と一致することを確認します。

### ステップ 4: リカバリに使用された設定ソースを確認する
-パラメータストア値:
```
AWS SSM 取得パラメータ\
 --名前 /lab/db/エンドポイント /lab/db/port /lab/db/name\
 --復号化あり\
 --リージョン us-west-2
```
-シークレットマネージャーのメタデータ:
```
AWS シークレットマネージャーがシークレット\ を説明
 --secret-id「taps/rds/mysql」\
 --リージョン (米国西部 2)
```
-レポートが正しいシークレット名/ARN と SSM パスを参照していることを確認します。

### ステップ 5: 人間によるレビュー+修正
-レポートとエビデンスの不一致を特定します。
-Markdownレポートに修正内容を直接追加:
 -根本原因の要約 (実際に失敗したこと)。
 -タイムラインの精度 (開始時と回復時期)
 -実行されたアクションと検証
 -予防措置。

### ステップ 6: ファイナライズしてアーカイブする
-修正したレポートをローカルに保存し、S3 に再アップロードします。
```
AWS、3個。<incident_id>/reports/IR/IR-report.md "s3://$REPORT_BUCKET/reports/ir--final.md」—region us-west-2
```
-オプション:簡単な要約をチケットシステムまたは変更ログに保存します。

## スクリプト用語集 (クイックリファレンス)
-`sanity_check.sh`: インフラ+アプリの正常性をローカル/リモートで検証します。オプションチェックのフラグをサポートします。
-`cleanup_verify.sh`: ap-northeast-1 と sa-east-1 の破棄後の AWS リソース検証。ブロックしているリソースが残っている場合は 1 (DIRTY) を返し、安全に再デプロイできる場合は 0 を返します。
-「cleanup_verify_gcp.sh`: newyork_gcpスタック（プロジェクト `taaops`、リージョン `us-central1`）の破棄後のGCPリソース検証。VPC、MIG、ILB、VPNトンネル、ルーター、ファイアウォール、シークレットをチェックします。終了コードコントラクトは「cleanup_verify.sh` と同じです。
-`scripts/publish_sanity_check.sh`: `sanity_check.sh` を S3 にアップロードし、署名済み URL を出力します。
-`scripts/filter_alarm_reports.sh`: レポート JSON を一覧表示し、アラームの状態/名前/重大度/時間でフィルタリングします。
-`scripts/download_alarm_reports.sh`: 一致するレポート JSON とマークダウンのペアを S3 からダウンロードします。
-「scripts/alarm.json」: SNS/ラムダテスト用の手動アラームペイロードのサンプル。
-`scripts/user_data.sh`: アプリ+依存関係用の EC2 ユーザーデータスクリプト。
-`python/bedrock_invoke_test_claude.py`: 環境変数を使用したシンプルなベッドロック呼び出しテスト。

### チェックリスト (人間が所有)
-[] アラームの詳細が CloudWatch に対して検証されました
-[] CloudWatch ログと照合して検証された証拠をログに記録します
-[] パラメータストアとシークレットが検証されました
-[] レポートが正確になるように修正されました
-[]「-final」というサフィックスが付いた最終レポートがアーカイブされました

## スタック・ディレクトリ・ノート
-アクティブな Terraform スタックは以下から実行されます。
 -`グローバル/`
 -`東京/`
 -`サンパウロ/`
-Terraform をリポジトリルートから実行しないでください。
-レガシールートレベルの Terraform ファイルは、参照用に `archive/root-terraform-from-root/` に移動されました。

---

## 手動クリーンアップ (ap-northeast-1)

接続の問題や以前のデプロイでリソースが孤立していたために `terraform_destroy .sh` を実行できない場合は、再デプロイする前に AWS コンソールまたは CLI で以下を手動で確認してください。

### 🔴 クリーンであることを確認する必要があります
これらは重複/孤立している可能性が最も高く、新規デプロイがブロックされたり破損したりします。
| リソース | コンソールの場所 | 何を探すべきか |
|---|---|---|
| **トランジットゲートウェイ** | VPC → トランジットゲートウェイ | 1 を超える余分な TGW をすべて削除します。TGW が孤立していると、VPN 接続が間違ったゲートウェイに接続されてしまう |
| **VPCS** | VPC → あなたの VPC | すべての `nihonmachi` /ラボ VPC を削除 — 以前にデプロイした VPC が重複すると TGW アタッチメントの競合が発生する |
| **VPN 接続** | VPC → サイト間 VPN | すべて削除 — 孤立しているものには「添付ID: なし」と表示される |
| **カスタマーゲートウェイ** | VPC → カスタマーゲートウェイ | `gcp_cgw_1` と `gcp_cgw_2` を削除 — これらは VPN を削除した後も残ります |
| **Aurora RDS クラスター** | RDS → データベース | 再デプロイする前にクラスター + インスタンスを削除 — RDS には最大 5 分かかり、上にデプロイできない |
| **NAT ゲートウェイ** | VPC → NAT ゲートウェイ | 手動で削除する必要があります — 実行したままにした場合、1 件あたりのコストは 1 か月あたり最大 32 USD |
| **エラスティック IPs** | EC2 → エラスティック IP | NAT ゲートウェイを削除した後に残った関連性のない EIP をすべてリリースする |

### 🟡 確認するがブロックする可能性は低い

| リソース | メモ |
|---|---|
| **DynamoDB** `taaops-terraform-state-lock` | `terraform_startup.sh` はブートストラップが存在する場合はそれをスキップします — そのままにしておいても安全です |
| **KMS キー** | すぐには削除できません (最低 7 日間のスケジュール)。そのままにしておくと、Terraform は新しいキーを作成します |
| **IAM ロール/ポリシー** | 名前が重複すると `apply` エラーが発生する — `taaops`/`tokyo` プレフィックスが付いているものがあればすべて削除する |
| **ラムダ関数** | `tokyo_ir_lambda` と `tokyo_secrets_rotation` が存在する場合は削除する |
| **S3 バケット** (非バックエンド) | `taaops-regional-waf-*`、`tokyo-backend-logs-*`、`tokyo-ir-reports-*` — 空にして削除 |
| **CloudWatch ロググループ** | オプション — Terraform はロググループを再作成しますが、古いロググループはロググループを蓄積します |
| **Kinesis Firehose** | `taops-regional-waf-firehose` が存在する場合は削除してください |
| **ALB** | ロードバランサー + ターゲットグループを削除 |
| **ACM 証明書** | 検証が保留中の場合は `tokyo_alb_origin` 証明書を削除する |
| **Route53 プライベートホストゾーン** | `日本町`ゾーンを確認 — Terraformがすでに存在すると競合する |

### 🟢 放っておいても安全
-`taaops-terraform-state-tokyo` S3 バケット — バケットを保持し、バケット内のステートファイルオブジェクトのみを削除します
-セキュリティグループ — VPC が削除されると自動的に削除されます

### 検証スクリプト

破棄または手動クリーンアップの後に `cleanup_verify.sh` (AWS) と `cleanup_verify_gcp.sh` (GCP) を実行して、再デプロイする前にブロッキングリソースが残っていないことを確認します。

```bash
chmod +x cleanup_verify.sh cleanup_verify_gcp.sh

# AWS — 東京 (ap-northeast-1) + サンパウロ (sa-east-1)
。/cleanup_verify.sh

GCP — newyork_gcp (プロジェクト:タプス、リージョン:us-central1)
。/cleanup_verify_gcp.sh

# 必要に応じてプロジェクト/リージョンをオーバーライドする
GCP_PROJECT=TAAOPS GCP_REGION=US-CENTRAL1。/cleanup_verify_gcp.sh
```

再デプロイしても安全な場合は `0` (CLEAN または WARN) を返し、ブロッキングリソースがまだ残っている場合は `1` (DIRTY) で終了します。`check_sao=False` を設定すると、AWS スクリプトのサンパウロでのチェックがスキップされます。

### CLI による重複のクイック (手動)

```bash
# VPC はいくつですか?
aws ec2 describe-vpcs--region ap-northeast-1\
 --query「Vpcs [*]。{id: VPCID、CIDR: CIDR: CidrBlock、名前:タグ [?キー== '名前'] | [0] .Value}」\
 --出力テーブル

# TGW はいくつですか?
aws ec2 describe-transit-gateways--region ap-northeast-1\
 --query「トランジットゲートウェイ [*]。{id: トランジットゲートウェイ ID、状態:州、名前:タグ [?キー== '名前'] | [0] .値}」\
 --出力テーブル

# VPN 接続が孤立していませんか?
aws ec2 describe-vpnconnections--region ap-northeast-1\
 --query「VPN 接続 [?ステート!= '削除済み']。{ID: VPN 接続 ID、状態:状態、TGW: トランジットゲートウェイ ID、アタッチ ID: トランジットゲートウェイアタッチメント ID}」\
 --出力テーブル

# NAT ゲートウェイ (忘れないで。実行したままの場合は $$)
aws ec2 describe-nat-gateways--region ap-northeast-1\
 --query「NATゲートウェイ [?州!= '削除済み']。{id: NAT ゲートウェイ ID、ステート:ステート:ステート、VPC: VPC ID}」\
 --出力テーブル
```


## 用語集



## 付録:IR + 翻訳ワークフロー (現在の展開)

図 A1.このリポジトリに現在デプロイされているコントロール/データフロー。SNS はアラームファンアウト通知や IR レポート対応通知に使用されます。Lambda への翻訳オーケストレーションは S3 イベント主導型です。

```マーメイド
フローチャート LR
 %% LAB4 現在デプロイされているワークフロー (テラフォーム検証済み)

 サブグラフ検出 ["検出レイヤー"]
 CWA ["クラウドウォッチアラーム"]
 CWL ["クラウドウォッチログ"]
 SNS アラート ["SNS: クラウドウォッチアラーム/リージョナルアラート"]
 SNS トリガー ["SNS: 東京 IR-トリガートピック"]
 終わり
  サブグラフ IR [「インシデントレポートパイプライン」]
 イル・ラムダ ["ラムダ:東京 IR レポーター"]
 インサイト ["ログインサイトクエリ"]
 Bedrock ["Amazon Bedrock (IR ナラティブ)"]
 IRS3 ["S3: 赤外線レポートバケット (JSON/MD)"]
 SNSReady ["SNS: 東京またはレポートトピック"]
 終わり

 サブグラフ翻訳 ["翻訳パイプライン"]
 InBucket ["S3: 翻訳入力バケット"]
 トランスラムダ ["Lambda: 翻訳プロセッサ"]
 翻訳 ["Amazon 翻訳 (+ 検出言語を理解しました)"]
 アウトバケット ["S3: 翻訳出力バケット"]
 終わり

 CWA--> SNS 警告
 SNS アラート--> リラムダ
 SNS トリガー--> イルラムダ

 CWL--> インサイト
 インサイト--> イルラムダ

 イルラムダ--> 岩盤
 岩盤--> イルラムダ
 イルラムダ--> IRS3
 イルラムダ--> SNS 対応

 IR ラムダ--> バケット内
 インバケット--> | S3 オブジェクト作成イベント | トランスラムダ
 トランスラムダ--> 翻訳
 翻訳--> トランスラムダ
 トランスラムダ--> アウトバケット
```

フィギュア A2。オペレーショナル・ランブックの調整を行うためのシーケンス・ビュー。

```マーメイド
シーケンス図
 参加者アラームを CloudWatch アラームとして使用
 SNS アラートトピックとしての参加者 SNSA
 参加者 URL を IR Lambda として使用
 参加者が CloudWatch ログインサイトとしてログに記録する
 参加者 BR をベッドロックとして
 S3 IR レポートとしての参加者 IRS3
 SNS レポート対応としての参加者 SNSR
 S3 翻訳入力としての参加者タグ
 参加者 TL を翻訳ラムダとして使用
 参加者の TR を Amazon 翻訳として使用
 参加者全員が S3 翻訳出力として出力される

 アラーム-> SNSA: アラーム通知
 SNSA->>IRL: ラムダを起動
 IRL->>ログ:インサイトクエリを実行
 ログ-->>IRL: エビデンス結果
 IRL->>BR: 赤外線サマリーを生成
 BR-->>IRL: ナラティブ・レスポンス
 URL->>IRS3: JSON /マークダウン IR レポートを書いてください
 URL->>SNSR: レポート準備完了通知を公開
 irl->>TIN: ソースドキュメントを翻訳用に書き込んでください
 Tin->>TL: オブジェクト作成トリガー
 TL->>TR: コンテンツを翻訳する
 TR-->>TL: 翻訳されたテキスト/ドキュメント
 TL->>tout: 翻訳された出力を書き込む
```

前提条件:
-現在、IR またはトランスレーションパス用の Step Functions ステートマシンはデプロイされていません。
-翻訳は、翻訳入力バケットの S3 ObjectCreated イベントから始まります。
-CloudWatch Logs は、IR Lambda によって実行されたログインサイトクエリを介して IR 証拠をフィードします。

### テラフォームグラフ

LAB4ネットワークとクロスクラウドトポロジのTerraform依存関係グラフ:

<img src="LAB4-DELIVERABLES/images/graph.svg" alt="Terraform graph of the LAB4 network and cross-cloud topology" width="1100">