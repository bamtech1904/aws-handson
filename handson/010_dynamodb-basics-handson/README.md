# 【AWSハンズオン】Amazon DynamoDBをTerraformで試してみた

# 概要

本フォルダは`Amazon DynamoDB ハンズオン入門`で使用するTerraformコードです。

Amazon DynamoDB の基本操作を「テーブル作成 → CLIでデータ操作 → コードを編集して拡張」という流れで体験します。`terraform plan` の差分（特に force replacement の有無）を見ながらテーブル定義を育てていくことで、DynamoDB自体の理解を深めます。

# 対象読者・前提

- DynamoDBを触ったことがない方
- Terraform CLI（`>= 1.9.0`）がインストール済みであること（テーブルのデプロイに使用）
- AWS CLI がインストール・認証済みであること（Terraformの認証情報として使用）

複数の AWS プロファイルを使い分けている場合は、`terraform.tfvars` に `profile = "<profile名>"` を指定してください（`terraform.tfvars.example` にコメントアウトで例があります）。

Step2以降のデータ操作は **AWS CloudShell** を使う想定です。ローカル端末にAWS CLIをセットアップしていなくても、ブラウザだけで進められます（Terraformのデプロイ自体はローカルで実行します）。

# コードの入手

以下いずれかの方法でTerraformコード一式を入手してください。

**方法1: curlでダウンロード**

```bash
mkdir dynamodb-basics-handson && cd dynamodb-basics-handson

for f in main.tf variables.tf outputs.tf terraform.tfvars.example; do
  curl -O "https://raw.githubusercontent.com/bamtech1904/aws-handson/main/handson/010_dynamodb-basics-handson/${f}"
done
```

**方法2: リポジトリをZIPダウンロード**

[GitHubリポジトリ](https://github.com/bamtech1904/aws-handson)の「Code」→「Download ZIP」から取得し、`handson/010_dynamodb-basics-handson/`配下のファイルを使用してください。

# 前提: 実行者のIAM権限

本ハンズオンはIAMユーザーを新規作成しないため、`terraform apply`を実行するご自身のIAMユーザーまたはロールに、あらかじめ以下の権限が必要です。

- DynamoDBテーブルの作成・削除等の操作権限（AWS管理ポリシー`AmazonDynamoDBFullAccess`など）
- Step2以降はCloudShellで操作するため、コンソールにログインしているIAMユーザー/ロールにも同じ権限（またはそのサブセット）が必要です

---

## Step 0. DynamoDBの基礎知識（3分）

| 用語                                    | 意味                                                                                               |
| --------------------------------------- | -------------------------------------------------------------------------------------------------- |
| テーブル                                | RDBのテーブルに相当。スキーマレス（属性はアイテムごとに自由）だが、キーだけは事前定義が必須        |
| パーティションキー（PK）                | アイテムを一意に特定する主キー（の一部）。DynamoDBの内部分散の単位でもある                         |
| ソートキー（SK）                        | PKと組み合わせて複合主キーを構成する任意項目。同じPK内でのソート・範囲検索に使う                   |
| GSI（グローバルセカンダリインデックス） | PK/SK以外の属性で検索したいときに追加する別インデックス                                            |
| キャパシティモード                      | `PAY_PER_REQUEST`（オンデマンド、呼び出し量課金）と `PROVISIONED`（読み書き容量を事前確保）の2種類 |

DynamoDB は「まずPKだけで小さく作り、アクセスパターンが増えたらGSIやSKで対応する」設計がしやすいのが特徴です。このハンズオンもその順番で進めます。

---

## コア編（〜30分）

### Step 1. テーブルをデプロイする

```bash
terraform init
terraform plan
terraform apply
```

`terraform plan` で表示される作成予定リソースは `aws_dynamodb_table.notes`（DynamoDBテーブル）1つだけです。デプロイ後、テーブル名を確認します。

```bash
terraform output
```

### Step 1b. CloudShellを開き、テーブル名を登録する

Step2以降のデータ操作は AWS CloudShell 上で行います。

1. [AWSマネジメントコンソール](https://console.aws.amazon.com/)を開く
2. 画面右上のツールバーにある **CloudShell** アイコンをクリックして起動する

CloudShellが起動したら、Step1で確認したテーブル名を環境変数に登録します。

```bash
export TABLE="dynamodb-basics-handson-notes"
```

（テーブル名は `main.tf` で固定文字列にしているため、常にこの値になります。念のため `terraform output -raw table_name` の結果と一致することを確認しておくとよいでしょう）

以降のStepのAWS CLIコマンドはすべてこのCloudShellのセッション内で実行します。

### Step 2. AWS CLIでCRUD一巡

```bash
# Create（登録）
aws dynamodb put-item \
  --table-name "$TABLE" \
  --item '{"NoteId": {"S": "note-001"}, "Title": {"S": "はじめてのメモ"}, "Body": {"S": "DynamoDBハンズオン"}}'

# Read（1件取得）
aws dynamodb get-item \
  --table-name "$TABLE" \
  --key '{"NoteId": {"S": "note-001"}}'

# Update（更新）
aws dynamodb update-item \
  --table-name "$TABLE" \
  --key '{"NoteId": {"S": "note-001"}}' \
  --update-expression "SET Body = :b" \
  --expression-attribute-values '{":b": {"S": "内容を更新しました"}}'

# Scan（全件取得）
# テーブル全体を読むためコストが高い。本番では極力避け、Query/GetItemを使う。
aws dynamodb scan --table-name "$TABLE"

# Delete（削除）
aws dynamodb delete-item \
  --table-name "$TABLE" \
  --key '{"NoteId": {"S": "note-001"}}'
```

`get-item`/`update-item`/`delete-item` はいずれもキー（`NoteId`）を指定するだけのO(1)アクセスです。`scan` だけがテーブル全体を舐める点に注意してください。

### Step 3. 複合キー（PK+SK）へ拡張する

`main.tf` の `aws_dynamodb_table.notes` を編集し、コメントアウトされている `range_key`・`CreatedAt` の `attribute` ブロックを有効化します。

```hcl
  hash_key  = "NoteId"
  range_key = "CreatedAt"

  attribute {
    name = "NoteId"
    type = "S"
  }

  attribute {
    name = "CreatedAt"
    type = "S"
  }
```

差分を確認します。

```bash
terraform plan
```

**ここが重要**: `hash_key`/`range_key`（キースキーマ）の変更はテーブルの**リソース置換（force replacement）**になります。`terraform plan` に`# forces replacement` の表示が出ることを確認し、既存データが失われる（テーブルが削除→再作成される）点を理解した上で `terraform apply` してください。

CFn版はテーブル名を固定するとリソース置換の際に新旧の名前が衝突して`CloudFormation cannot update a stack when a custom-named resource requires replacing`というエラーで失敗するため、物理名をCloudFormationの自動生成に任せていました（CFnは「新しいリソースを先に作ってから古いリソースを消す」順序を取るため）。Terraformは逆で、リソース置換の既定動作が**「先に古いリソースを消してから新しいものを作る」**（`create_before_destroy` を明示しない限り）ため、名前が固定でも衝突しません。その代わり、置換が完了するまでの間はテーブルが一時的に存在しない空白時間が生まれます——この違いも実際に `terraform apply` の出力（`Destroying...` の後に `Creating...` が続くログ）で確認しておくとよいでしょう。

```bash
terraform apply
```

複合キーで2件登録し、`query` でソートキーの範囲検索を試します。

```bash
aws dynamodb put-item --table-name "$TABLE" \
  --item '{"NoteId":{"S":"note-001"},"CreatedAt":{"S":"2026-09-01T10:00:00Z"},"Title":{"S":"1件目"}}'
aws dynamodb put-item --table-name "$TABLE" \
  --item '{"NoteId":{"S":"note-001"},"CreatedAt":{"S":"2026-09-05T10:00:00Z"},"Title":{"S":"2件目"}}'
```

まずコンソールでソートキー範囲検索の絞り込み方を確認します（任意）。

1. DynamoDBコンソール → 対象テーブル → 「テーブルアイテムの探索」を開く
2. 上部で `Scan` ではなく `Query` を選択
3. パーティションキー（`NoteId`）に `note-001` を入力
4. ソートキー（`CreatedAt`）の条件で `Between` を選び、`2026-09-01T00:00:00Z` と `2026-09-01T23:59:59Z` を入力して実行

登録した2件目（`2026-09-05T...`）は範囲外のため表示されず、1件目だけが返ります。ここで**「フィルタ」欄とは別物**である点に注意してください。ソートキー条件はKeyConditionExpressionの一部としてDynamoDBが読み取る範囲そのものを絞り込みます（読み取り容量もその分だけ）。一方フィルタは範囲内の全アイテムを読み取った**後**に絞り込むため、読み取り容量は減りません。効率を求めるならソートキー条件、PK/SK以外の属性で絞りたいだけならフィルタ、と使い分けます。

同じ絞り込みをCLIでも実行してみます。

```bash
aws dynamodb query \
  --table-name "$TABLE" \
  --key-condition-expression "NoteId = :id AND CreatedAt BETWEEN :from AND :to" \
  --expression-attribute-values '{
    ":id": {"S": "note-001"},
    ":from": {"S": "2026-09-01T00:00:00Z"},
    ":to": {"S": "2026-09-01T23:59:59Z"}
  }'
```

`scan` と違い、`query` はPK（+SK範囲）で絞り込むため対象パーティションだけを読みます。

### コア編の後片付け

```bash
terraform destroy
```

ここで一区切り。発展編は任意（続けてもよいし、日を改めてもよい）。

---

## 発展編（任意・+20〜30分）

コア編と同じ手順（`terraform plan` → 内容確認 → `terraform apply`）でテーブルを再作成しながら進めます。

### Step 4. GSIを追加する

「投稿者（`UserId`）ごとにメモを検索したい」という新しいアクセスパターンをGSIで実現します。ここでは**既存アイテムがあるテーブルにGSIを後から追加**し、既存データが自動でインデックスに取り込まれる（バックフィル）様子を体験します。

まず、GSIを追加する前の状態でテーブルを作成します（`main.tf` はStep3で複合キーにした状態のまま、`UserId` 関連のブロックはコメントアウトのままにしておきます）。

```bash
terraform apply
```

続けてCloudShellで、`UserId` を持つアイテムを2件登録します（CloudShellのセッションが切れている場合は、Step1bの `export TABLE=...` を再実行してください）。

```bash
aws dynamodb put-item --table-name "$TABLE" \
  --item '{"NoteId":{"S":"note-001"},"CreatedAt":{"S":"2026-09-10T09:00:00Z"},"UserId":{"S":"user-a"}}'
aws dynamodb put-item --table-name "$TABLE" \
  --item '{"NoteId":{"S":"note-002"},"CreatedAt":{"S":"2026-09-10T09:05:00Z"},"UserId":{"S":"user-b"}}'
```

**GSIに載るのは、インデックスのキー属性（ここでは `UserId`）を持つアイテムだけ**です（スパースインデックス）。`UserId` を持たないアイテムは、GSIを作ってもインデックス側には現れず、GSIへの `query` では返りません。今回は `UserId` 付きのアイテムをGSI作成の前に登録しておくことで、既存アイテムがバックフィルされる様子を確認できます（GSI作成後に登録した `UserId` 付きアイテムも、自動的にインデックスへ反映されます）。

次に、`main.tf` の `UserId` 用 `attribute` ブロックと `global_secondary_index` ブロックを有効化します。

```hcl
  attribute {
    name = "UserId"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "UserId"
    projection_type = "ALL"
  }
```

（`billing_mode = PAY_PER_REQUEST` のままなら `read_capacity`/`write_capacity` は不要です。Step5でプロビジョンドに切り替える場合はGSI側にも容量指定が必要になります）

差分を確認してから適用します。Step3と違い、GSI追加は**置換を伴わない**インプレース更新である点に注目してください。

```bash
terraform plan
terraform apply
```

GSIは作成直後すぐには使えません。既存アイテムのバックフィルが終わり、`IndexStatus` が `CREATING` から `ACTIVE` になるまでは、そのインデックスに対して `query` を実行できません（バックフィルには多少時間がかかることがあります）。CloudShellで状態を確認します。

```bash
aws dynamodb describe-table --table-name "$TABLE" \
  --query "Table.GlobalSecondaryIndexes[].{Name:IndexName,Status:IndexStatus}"
```

`Status` が `ACTIVE` になったら、`UserIdIndex` を指定して `query` を実行します。

```bash
aws dynamodb query \
  --table-name "$TABLE" \
  --index-name UserIdIndex \
  --key-condition-expression "UserId = :u" \
  --expression-attribute-values '{":u": {"S": "user-a"}}'
```

`user-a` の1件（`note-001`）だけが返り、`user-b` の `note-002` は含まれません。GSIを使うと、テーブルのキー（`NoteId`）以外の属性でもScanなしで検索できます。なお、GSIへの読み取りは結果整合性のみで、`--consistent-read`（強い整合性）は指定できません（指定するとエラーになります）。

### Step 5. キャパシティモードと料金の勘所

`billing_mode` を `PROVISIONED` に切り替え、読み書き容量を明示します（テーブル本体・GSIそれぞれに容量指定が必要です）。

```hcl
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "UserId"
    projection_type = "ALL"
    read_capacity   = 5
    write_capacity  = 5
  }
```

判断の目安:

- **オンデマンド（`PAY_PER_REQUEST`）**: アクセス量が読めない・検証中・呼び出しが少ない場合に安全です。呼び出しゼロなら課金もほぼゼロです。
- **プロビジョンド（`PROVISIONED`）**: アクセスパターンが安定していて、Auto Scalingと組み合わせられる本番向けです。容量を確保している間は呼び出しが無くても課金され続ける点に注意してください（無料利用枠の範囲や具体的な料金はAWS公式のDynamoDB料金ページを確認すること）。

**発展編を試したら、忘れず `terraform destroy` で片付けてください**（プロビジョンドのまま放置しない）。

---

# 想定コスト

- コア編（オンデマンドモードのみ）: 実質 **~$0**（DynamoDBの無料利用枠内で収まる想定）
- 発展編でプロビジョンドモードに切り替えた場合: 容量を確保している間、少額課金の可能性があります。検証後は速やかに `terraform destroy` してください

# 後片付け

```bash
terraform destroy
```
