output "cluster_id" {
  description = "Aurora DSQLクラスターの識別子"
  value       = aws_dsql_cluster.this.identifier
}

output "cluster_endpoint" {
  description = "IAM認証トークン経由の psql 接続に使用するエンドポイント"
  value       = local.cluster_endpoint
}
