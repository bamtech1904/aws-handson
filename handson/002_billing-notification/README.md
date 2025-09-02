# AWSサービスコストを日次でslackに通知するシステムを実装

# 概要
今月で対象アカウントにかかっているAWSコストをAWS Lambdaを使って実装できるようにする。

# 手順
## 1. 外部ライブラリ（requests）の準備

Lambda関数では標準でrequestsライブラリが使えないため、Layerとして追加が必要

ローカルでの準備:
```
mkdir python
pip install -t python requests
zip -r9 layer.zip python
```

## 2. Lambda Layerの作成

1. AWS Lambda コンソールの「Layers」画面で「Create layer」
2. 作成したzipファイル（layer.zip）をアップロード
3. 「Create」をクリックしてLayer作成

## 3. Lambda関数にLayerを追加

1. Lambda関数のCodeタブ → Layerページ → 「Add a layer」
2. 作成したLayerのARNを指定
3. 「Add」をクリック

## 4. 動作確認

- テスト実行でrequestsモジュールが正常に動作することを確認
- エラーなく実行完了（Response: null、ステータス200）

## 5. CloudFormationスタック作成
## 6. Lambdaにソースコードをデプロイ
