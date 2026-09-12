terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.100.0, < 6.0.0" # aws_dsql_cluster が 5.100.0 以降でサポートされるため
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  # aws_dsql_cluster リソースには接続エンドポイントを表す属性が無いため、
  # AWSが払い出すエンドポイント形式（<identifier>.dsql.<region>.on.aws）から組み立てる。
  cluster_endpoint = "${aws_dsql_cluster.this.identifier}.dsql.${var.region}.on.aws"
}

# 単一リージョンのAurora DSQLクラスター。テーブルスキーマ（DDL）はTerraformの
# 管轄外: クラスターリソース自体はスキーマを持たず、接続後にIAM認証トークン経由の psql から
# CREATE TABLE 等を実行する運用になる。手順はREADMEを参照。
resource "aws_dsql_cluster" "this" {
  deletion_protection_enabled = false

  tags = {
    Name = "aurora-dsql-handson"
  }
}
