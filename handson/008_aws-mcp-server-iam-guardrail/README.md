# 【AWSハンズオン】AWS MCP ServerをClaude Codeにつないで、AIにAWS環境を触らせてみた

# 概要
本フォルダは`AWS MCP ServerをClaude Codeにつないで、AIにAWS環境を触らせてみた`のハンズオンで使用するCloudFormationテンプレートです。

AWS公式のマネージドMCP Server（GA版）をClaude Codeに接続し、自然言語でAWS環境を操作したうえで、IAMの条件キー`aws:ViaAWSMCPService`を使ってAIエージェント経由の操作だけを制限する手順を扱います。

# テンプレートの入手

以下いずれかの方法でテンプレートファイル（`aws-mcp-handson-cloudformation.yaml`）を入手してください。

**方法1: curlでダウンロード**
```bash
curl -o aws-mcp-handson-cloudformation.yaml \
  https://raw.githubusercontent.com/bamtech1904/aws-handson/main/handson/008_aws-mcp-server-iam-guardrail/aws-mcp-handson-cloudformation.yaml
```

**方法2: リポジトリをZIPダウンロード**

[GitHubリポジトリ](https://github.com/bamtech1904/aws-handson)の「Code」→「Download ZIP」から取得し、`handson/008_aws-mcp-server-iam-guardrail/aws-mcp-handson-cloudformation.yaml`を使用してください。

# このテンプレートで作成されるもの

- ハンズオン用IAMユーザー（`aws-mcp-handson-user`）とコンソールサインイン用パスワード
- ハンズオン③（自然言語でのAWS環境操作）に必要な最小権限（`ec2:DescribeRegions` / S3のバケット一覧・作成・削除など）

# ハンズオン中に手動で行うもの（あえてテンプレートに含めていません）

- **ハンズオン①**: `AWSMCPSignInOAuthAccessPolicy`を`aws iam attach-user-policy`でアタッチ
- **ハンズオン④**: `aws:ViaAWSMCPService`条件のDenyポリシーを`aws iam put-user-policy`でアタッチ

テンプレート内に該当箇所をコメントアウトで残しているので、内容の確認・コピー用に利用してください。

# セットアップ手順

1. スタック作成時に`ConsolePassword`パラメータでコンソールサインイン用パスワードを指定
2. スタック作成後、Outputsの`ConsoleSignInUrl`と`IamUserName`、指定したパスワードでOAuthサインインを実行

# 後片付け

- ハンズオンで作成したS3バケットを削除
- ハンズオン④で追加したインラインポリシー（`DenyMCPDelete`など）を削除
- 本スタックを削除（IAMユーザー・ベースポリシーを削除）
