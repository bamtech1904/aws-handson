variable "region" {
  description = "AWS リージョン（Aurora DSQLの対応リージョンを指定してください）"
  type        = string
  default     = "ap-northeast-1"
}

variable "profile" {
  description = "使用する AWS プロファイル名（未指定なら AWS_PROFILE 環境変数 → default プロファイルの順で解決される）"
  type        = string
  default     = null
}
