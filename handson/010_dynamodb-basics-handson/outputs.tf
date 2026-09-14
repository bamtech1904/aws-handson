output "table_name" {
  description = "作成したDynamoDBテーブル名"
  value       = aws_dynamodb_table.notes.name
}
