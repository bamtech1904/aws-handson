# 【AWSハンズオン】Amazon Aurora DSQLを試しに使ってみた

# 概要

本フォルダは`Amazon Aurora DSQLを試しに使ってみた`のハンズオンで使用するCloudFormationテンプレートです。

AWS初学者向けに、サーバーレスの分散SQLデータベースであるAmazon Aurora DSQL（単一リージョン構成）にCloudShellから`psql`で接続し、基本的なSQL操作を体験する手順を扱います。サービス自体の解説は別資料で扱っているため、本ハンズオンでは実践部分のみを対象とします。

# テンプレートの入手

以下いずれかの方法でテンプレートファイル（`aurora-dsql-handson-cloudformation.yaml`）を入手してください。

**方法1: curlでダウンロード**
```bash
curl -o aurora-dsql-handson-cloudformation.yaml \
  https://raw.githubusercontent.com/bamtech1904/aws-handson/main/handson/009_aurora-dsql-handson/aurora-dsql-handson-cloudformation.yaml
```

**方法2: リポジトリをZIPダウンロード**

[GitHubリポジトリ](https://github.com/bamtech1904/aws-handson)の「Code」→「Download ZIP」から取得し、`handson/009_aurora-dsql-handson/aurora-dsql-handson-cloudformation.yaml`を使用してください。

# このテンプレートで作成されるもの

- Amazon Aurora DSQLクラスタ（単一リージョン、削除保護は無効）のみ

IAMユーザーは作成しません。各自ログイン済みのAWSアカウント（IAMユーザー／ロール）でそのまま操作してください。

# 前提: 実行者のIAM権限

本ハンズオンはIAMユーザーを新規作成しないため、スタックを作成・操作するご自身のIAMユーザーまたはロールに、あらかじめ以下の権限が必要です。

- `dsql:DbConnectAdmin`（クラスタへの接続用認証トークンを取得するための権限）
- CloudShellの利用権限（マネージドポリシー`AWSCloudShellFullAccess`など）
- クラスタ作成・削除等の操作権限（AWS管理ポリシー`AmazonAuroraDSQLFullAccess`など）

# セットアップ手順

0. Aurora DSQLの[対応リージョン一覧](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/index.html)を確認し、対応リージョンでスタックを作成してください
1. 対応リージョンでスタックを作成

# ハンズオン手順（手動で行うもの）

## 1. クラスタの状態確認

Aurora DSQLコンソールを開き、作成されたクラスタのステータスが`ACTIVE`になっていることを確認します。

## 2. CloudShellを開く

コンソール左下（または画面上部）のCloudShellアイコンからCloudShellを起動します。

## 3. psqlクライアントをインストール

CloudShellにはPostgreSQLクライアントが入っていないため、以下のコマンドでインストールします。

```bash
sudo dnf install -y postgresql15
```

## 4. 認証トークンを取得して接続

Aurora DSQLはパスワードの代わりにIAM認証トークンで接続します。スタックのOutputsに表示された`ClusterEndpoint`と、スタックを作成したリージョンを使って以下を実行してください。

```bash
export CLUSTER_ENDPOINT=<Outputsの ClusterEndpoint>
export AWS_REGION=<スタックを作成したリージョン（例: us-east-1）>

TOKEN=$(aws dsql generate-db-connect-admin-auth-token \
  --expires-in 3600 \
  --region "$AWS_REGION" \
  --hostname "$CLUSTER_ENDPOINT")

PGSSLMODE=require PGPASSWORD="$TOKEN" \
psql --dbname postgres \
  --username admin \
  --host "$CLUSTER_ENDPOINT"
```

`postgres=>`のプロンプトが表示されれば接続成功です。

認証トークンの有効期限は最大1週間（デフォルト15分、上記コマンドでは3600秒＝1時間に設定）で、期限が切れると新しいトークンの取得が必要です。

## 5. 基本的なSQL操作を試す

```sql
-- テーブル作成
CREATE TABLE handson_items (
  id INT PRIMARY KEY,
  name VARCHAR(100),
  price INT
);

-- データ登録
INSERT INTO handson_items (id, name, price) VALUES (1, 'apple', 150);
INSERT INTO handson_items (id, name, price) VALUES (2, 'banana', 100);

-- 参照
SELECT * FROM handson_items;

-- 更新
UPDATE handson_items SET price = 180 WHERE id = 1;

-- 削除
DELETE FROM handson_items WHERE id = 2;

-- 確認
SELECT * FROM handson_items;
```

# 後片付け

- 本スタックを削除（Aurora DSQLクラスタを削除）
