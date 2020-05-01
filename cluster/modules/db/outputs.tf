
output "endpoint" {
  value = aws_rds_cluster.db_cluster.endpoint
}

output "port" {
  value = aws_rds_cluster.db_cluster.port
}

output "db_name" {
  value = aws_rds_cluster.db_cluster.database_name
}

output "db_user" {
  value = aws_rds_cluster.db_cluster.master_username
}

output "db_pass" {
  value = aws_rds_cluster.db_cluster.master_password
}