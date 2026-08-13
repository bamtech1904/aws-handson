# 【AWSハンズオン】AWS MCP ServerをClaude Codeにつないで、AIにAWS環境を触らせてみた

# 概要
本フォルダは`AWS MCP ServerをClaude Codeにつないで、AIにAWS環境を触らせてみた`のハンズオンで使用するCloudFormationテンプレートです。

AWS公式のマネージドMCP Server（GA版）をClaude Codeに接続し、自然言語でAWS環境を操作したうえで、IAMの条件キー`aws:ViaAWSMCPService`を使ってAIエージェント経由の操作だけを制限する手順を扱います。

# ワンクリックでスタック作成

[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=ap-northeast-1#/stacks/new?stackName=aws-mcp-handson&templateURL=https%3A%2F%2Fraw.githubusercontent.com%2Fbamtech1904%2Faws-handson%2Fmain%2Fhandson%2F008_aws-mcp-server-iam-guardrail%2Faws-mcp-handson-cloudformation.yaml)

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
