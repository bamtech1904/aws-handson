# 【AWSハンズオン】Amazon Aurora DSQLをTerraformで試してみた

# 概要

本フォルダは`Amazon Aurora DSQL ハンズオン入門`で使用するTerraformコードです。

Amazon Aurora DSQL の以下操作についてハンズオンします。
1. クラスター作成（Terraform）
2. psqlでスキーマ・データ操作（SQL）
3. DML/DDL分離とOCCを体験

Terraformが担うのはクラスターのプロビジョニングまで。テーブルのスキーマ（DDL）はデプロイ後にSQLで手動作成します。「インフラはIaC、スキーマはSQLマイグレーション」という一般的なRDBの管理スタイルをここで体感します。

# 対象読者・前提

- Aurora DSQLを触ったことがない方
- PostgreSQLの基本的なSQL（CREATE TABLE / INSERT / SELECT / UPDATE / DELETE）が分かるとスムーズです（わからなくてもOK）
- Terraform CLI（`>= 1.9.0`）がインストール済みであること
- AWS CLI がインストール・認証済みであること（`aws dsql` サブコマンドを使うため、比較的新しいバージョンの AWS CLI v2 が必要。`aws dsql help` が通ることを事前に確認してください）

複数の AWS プロファイルを使い分けている場合は、`terraform.tfvars` に `profile = "<profile名>"` を指定してください（`terraform.tfvars.example` にコメントアウトで例があります）。`aws` コマンドを直接実行する箇所（Step2以降）では、各実行時に `--profile <profile名>` を追加してください。

# コードの入手

以下いずれかの方法でTerraformコード一式を入手してください。

**方法1: curlでダウンロード**

```bash
mkdir aurora-dsql-handson && cd aurora-dsql-handson

for f in main.tf variables.tf outputs.tf terraform.tfvars.example; do
  curl -O "https://raw.githubusercontent.com/bamtech1904/aws-handson/main/handson/009_aurora-dsql-handson/${f}"
done
```

**方法2: リポジトリをZIPダウンロード**

[GitHubリポジトリ](https://github.com/bamtech1904/aws-handson)の「Code」→「Download ZIP」から取得し、`handson/009_aurora-dsql-handson/`配下のファイルを使用してください。

# 前提: 実行者のIAM権限

本ハンズオンはIAMユーザーを新規作成しないため、`terraform apply`を実行するご自身のIAMユーザーまたはロールに、あらかじめ以下の権限が必要です。

- クラスター作成・削除等の操作権限（AWS管理ポリシー`AmazonAuroraDSQLFullAccess`など）
- `dsql:DbConnectAdmin`（作成したクラスターへの接続用認証トークンを取得するための権限）

---

## Step 0. Aurora DSQLの基礎知識（3分）

| 用語                               | 意味                                                                                                                                                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| クラスター                         | Aurora DSQLの管理単位。作成するとリージョン内で自動的に3AZへレプリケートされる                                                                                                                   |
| DPU（Distributed Processing Unit） | 課金の基本単位。コンピュート・読み書き・CDCストリーミングなど全てのDB活動を正規化した単位。アクティビティがゼロなら消費もゼロ                                                                    |
| IAM認証トークン                    | パスワードの代わりに使う短命な認証トークン。`aws dsql generate-db-connect-admin-auth-token` で発行する                                                                                           |
| DDL/DML分離                        | 1つのトランザクション内でスキーマ変更（DDL、例: `CREATE TABLE`）とデータ操作（DML、例: `INSERT`）を混在できない制約。分散環境でスキーマ変更を安全に伝播させるための設計                          |
| 楽観的並行制御                     | 更新時にロックを取らず、コミット時に競合を検出する方式。競合するとコミットが失敗し、クライアント側でリトライが必要になることがある                                                               |
| ネットワークモデル                 | Aurora DSQLはそもそもVPCに配置する概念を持たないサーバーレスサービス。クラスターは作成時から公開エンドポイントを持ち、安全性はネットワーク隔離ではなくIAM認証（短命トークン）＋TLS必須で担保する |

通常のAurora（PostgreSQL/MySQL互換）との違いはトランザクションの挙動に出ます。通常のAurora PostgreSQLはDDLも完全にトランザクショナルで、DMLと混在させてもROLLBACKすればCREATE TABLEごと取り消せます。Aurora DSQLは分散カタログを安全に伝播させるため、DDLとDMLの混在自体を禁止します（Step3で体験）。また競合検出も通常のAuroraが行レベルロックで先に防ぐ（悲観的並行制御）のに対し、Aurora DSQLはロックを取らずコミット時に競合を検出する楽観的並行制御を使います（発展編Step4で体験）。

---

## コア編（〜30分）

### Step 1. クラスターをデプロイする

```bash
terraform init
terraform plan
terraform apply
```

`terraform plan` で表示される作成予定リソースは `aws_dsql_cluster.this`（Aurora DSQLクラスター）1つだけです。クラスターが `ACTIVE` になるまで数分かかることがあります。デプロイ後、接続エンドポイントを確認します。

```bash
terraform output
ENDPOINT=$(terraform output -raw cluster_endpoint)
```

### Step 2. IAM認証トークンでpsql接続し、テーブルを作る

```bash
# IAM認証トークンを発行（有効期限1時間）。パスワードの代わりにこれを使う
TOKEN=$(aws dsql generate-db-connect-admin-auth-token \
  --region ap-northeast-1 \
  --expires-in 3600 \
  --hostname "$ENDPOINT")

# psqlで接続（データベース名は固定で postgres、SSL必須）
PGPASSWORD="$TOKEN" psql \
  "host=$ENDPOINT dbname=postgres user=admin sslmode=require"
```

> **必要なIAM権限**: 上記のように `admin` ロールで接続する場合、実行するIAMユーザー/ロールには対象クラスターのARNにスコープした `dsql:DbConnectAdmin` が必要です（`terraform apply` を実行した権限があれば通常は含まれています）。
>
> ```json
> {
>   "Effect": "Allow",
>   "Action": "dsql:DbConnectAdmin",
>   "Resource": "arn:aws:dsql:ap-northeast-1:<account_id>:cluster/<cluster_id>"
> }
> ```
>
> なお `aws dsql generate-db-connect-admin-auth-token` の実行自体はAWSへAPIを呼ばずローカルでSigV4署名を組み立てるだけの操作なので、このコマンド自体に紐づくIAM権限はありません。権限チェックが働くのは、発行したトークンで実際にクラスターへ接続を試みた瞬間です。カスタムDBロール（`dsql:DbConnect`）で接続する場合の権限設定は発展編のStep5を参照してください。

接続できたら、テーブルを作成してCRUDを一巡します（psqlのプロンプト内で実行）。

```sql
-- Create（テーブル作成）
CREATE TABLE notes (
  note_id    uuid primary key default gen_random_uuid(),
  title      text not null,
  body       text,
  created_at timestamptz not null default now()
);

-- Create（データ登録）
INSERT INTO notes (title, body) VALUES ('はじめてのメモ', 'Aurora DSQLハンズオン');

-- Read（全件取得）
SELECT * FROM notes;

-- Update（更新）
UPDATE notes SET body = '内容を更新しました' WHERE title = 'はじめてのメモ';

-- Delete（削除）
DELETE FROM notes WHERE title = 'はじめてのメモ';
```

### Step 2b（別解）. Query Editorでpsqlなしに同じ操作を試す

`psql` をインストールしなくても、AWSマネジメントコンソールの **Aurora DSQL Query Editor**（2025年11月リリース）から同じCRUD操作を試せます。IAM認証トークンの発行もローカルのクライアントセットアップも不要で、ブラウザだけで完結します。

**前提条件**

- クラスターのエンドポイントがパブリックアクセス可能であること（本ハンズオンのコードはリソースベースポリシー等でブロックしていないため、デフォルトでこの条件を満たします）
- 接続に使うIAMユーザー/ロールが、クラスターへの接続権限（`dsql:DbConnect` / `dsql:DbConnectAdmin`）を持っていること。Step2でpsql接続に使ったIAMプリンシパルと同じものであればそのまま使えます

**手順**

1. [Aurora DSQLコンソール](https://console.aws.amazon.com/dsql) を開く
2. ナビゲーションペインで **Query Editor** を選択する（または **Clusters** ページで対象クラスターを選び、**Connect with Query editor** から直接開いてもよい）
3. 接続がなければ **Connect**（または Cluster Explorer ペインの **+**）を選び、対象クラスターに接続する
4. クエリエディタのタブにSQLを入力し、**Run** で実行する。Step2で使ったCRUD文（`CREATE TABLE` / `INSERT` / `SELECT` / `UPDATE` / `DELETE`）をそのまま流し込める
5. 実行結果は下部の **Results** パネルに表示される（1クエリあたり最大10,000行まで）

**Tips**

- 画面左の **Cluster Explorer** から、データベース・スキーマ・テーブルをGUIでブラウズできます
- `EXPLAIN ANALYZE VERBOSE` を実行すると、そのSQL文が消費した Compute / Read / Write / Total のDPU見積もりを確認できます。「想定コスト」セクションで触れているDPU課金を、クエリ単位で体感するのに向いています
- ブラウザタブを閉じたりコンソールから離れたりすると、接続状態・入力中のクエリ・実行結果は保存されずに失われます

### Step 3. DDL/DML分離の制約を実際に踏む

Aurora DSQLは分散SQLの特性上、**1つのトランザクション内でDDLとDMLを混在できません**。これを実際にエラーとして体験します。

```sql
BEGIN;
CREATE TABLE notes_v2 (
  note_id uuid primary key default gen_random_uuid(),
  title   text not null
);
INSERT INTO notes_v2 (title) VALUES ('同一トランザクションでのINSERT');
COMMIT;
```

→ `INSERT` の実行時（またはCOMMIT時）にエラーになることを確認します。DDLとDMLは**別トランザクションに分ける**のが正しい使い方です。

```sql
CREATE TABLE notes_v2 (
  note_id uuid primary key default gen_random_uuid(),
  title   text not null
);

INSERT INTO notes_v2 (title) VALUES ('別トランザクションでのINSERT');
SELECT * FROM notes_v2;
```

「制約を実際にエラーとして踏んでから正しいやり方に直す」ことで、分散SQL特有の設計思想が体感できます。

### コア編の後片付け

```sql
\q
```

```bash
terraform destroy
```

ここで一区切り。発展編は任意（続けてもよいし、日を改めてもよい）。

---

## 発展編（任意・+20分）

コア編と同じ手順（`terraform plan` → 内容確認 → `terraform apply`）でクラスターを再作成しながら進めます。

### Step 4. 楽観的並行制御による競合を体験する

ターミナルを2枚開き、それぞれで `$ENDPOINT` に対してpsql接続します（Step2と同じ手順でトークンを発行し直す）。

セッションA・セッションB両方で同じテーブルを用意しておきます。

```sql
CREATE TABLE counters (id int primary key, value int not null);
INSERT INTO counters (id, value) VALUES (1, 0);
```

セッションAで（まだCOMMITしない）:

```sql
BEGIN;
UPDATE counters SET value = value + 1 WHERE id = 1;
```

セッションBで（同じ行を更新してCOMMITまで進める）:

```sql
BEGIN;
UPDATE counters SET value = value + 1 WHERE id = 1;
COMMIT;
```

セッションAに戻って `COMMIT;` を実行する → 競合が検出されコミットが失敗することを確認します。ロックを先に取る通常のRDBMSとの違い（コミット時に初めて競合が判明する）がポイントです。失敗した場合はトランザクションを最初からやり直す（リトライ）のがAurora DSQLでの正しい対処法です。

### Step 5. カスタムロールでの接続制御

`admin` ロールではなく、`dsql:DbConnect` 権限のみを持つIAMロール/ユーザーで接続してみます。

```bash
# admin ロール用ではなく、カスタムロール用のトークン発行コマンドを使う
aws dsql generate-db-connect-auth-token \
  --region ap-northeast-1 \
  --expires-in 3600 \
  --hostname "$ENDPOINT"
```

接続するIAMプリンシパルに、対象クラスターへの `dsql:DbConnect` を許可するIAMポリシーをアタッチする必要があります（今回のコードではIAMロールまでは作成していないので、試す場合は既存のIAMユーザー/ロールに一時的にポリシーを追加するか、別途IAMロールを作って試してください）。

### マルチリージョンクラスターについて（概念紹介のみ）

Aurora DSQLは `multi_region_properties` を使うと複数リージョンにまたがるクラスターを構成できます（`witness_region` で第三のリージョンを監視役に指定し、`aws_dsql_cluster_peering` でピアクラスターを結びつける）。可用性がさらに高まる一方、IAM権限の追加設定や複数リージョンにまたがる削除確認が必要になり複雑さが増すため、本ハンズオンでは実デプロイは行いません。

**発展編を試したら、忘れず `terraform destroy` で片付けてください。**

---

# 想定コスト

- DPU（Distributed Processing Unit）使用量課金 + ストレージ GB-月。データベース活動がゼロの間はDPU消費もゼロ
- 本ハンズオンの操作量であれば無料利用枠内で収まる想定です。ただし放置すると微小なストレージ課金が発生し続けるため、検証後は速やかに `terraform destroy` してください

# 後片付け

```bash
terraform destroy
```
