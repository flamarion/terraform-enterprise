output "public_fqdn" {
  value = aws_route53_record.flamarion.fqdn
}

output "lb_fqdn" {
  value = aws_lb.flamarion_lb.dns_name
}

output "db_cluster_endpoint" {
  value = module.tfe_db_cluster.endpoint
}

output "db_cluster_port" {
  value = module.tfe_db_cluster.port
}

output "db_cluster_name" {
  value = module.tfe_db_cluster.db_name
}
