terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

# パーティションキーのみの単純なテーブル。複合キー化・GSI追加・キャパシティモード変更は
# READMEの手順に沿って自分でこのファイルを編集し、差分（force replacement の有無）を
# 見ながら学ぶ。
#
# テーブル名は固定文字列にしている。CFn版はキースキーマ変更時のリソース置換で
# 「新→旧の順に名前が衝突して更新が失敗する」問題を避けるため物理名の自動生成に
# 頼っていたが、Terraformはリソース置換時に既定で「旧→新」の順（destroy してから
# create）で処理するため、名前が固定でも衝突しない。詳しくはREADME Step3を参照。
resource "aws_dynamodb_table" "notes" {
  name         = "dynamodb-basics-handson-notes"
  billing_mode = "PAY_PER_REQUEST"
  # billing_mode   = "PROVISIONED"
  # read_capacity  = 5
  # write_capacity = 5

  hash_key = "NoteId"
  # range_key = "CreatedAt"

  attribute {
    name = "NoteId"
    type = "S"
  }

  # attribute {
  #   name = "CreatedAt"
  #   type = "S"
  # }

  # attribute {
  #   name = "UserId"
  #   type = "S"
  # }

  # global_secondary_index {
  #   name            = "UserIdIndex"
  #   hash_key        = "UserId"
  #   projection_type = "ALL"
  #   read_capacity   = 5
  #   write_capacity  = 5
  # }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "dynamodb-basics-handson"
  }
}
