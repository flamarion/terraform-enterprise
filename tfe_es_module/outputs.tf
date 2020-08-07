output "public_fqdn" {
  value = aws_route53_record.flamarion.fqdn
}

output "lb_fqdn" {
  value = aws_lb.flamarion_lb.dns_name
}


# DB Cluster
output "db_cluster_endpoint" {
  value = module.tfe_db_cluster.endpoint
}

output "db_cluster_port" {
  value = module.tfe_db_cluster.port
}

output "db_cluster_name" {
  value = module.tfe_db_cluster.db_name
}

output "db_cluster_user" {
  value = module.tfe_db_cluster.db_user
}

output "db_cluster_pass" {
  value = module.tfe_db_cluster.db_pass
}


# SG
output "lb_sg_id" {
    value = module.tfe_lb_sg.sg_id
}

output "db_sg_id" {
    value = module.tfe_db_sg.sg_id
}

output "instances_sg_id" {
    value = module.tfe_instances_sg.sg_id
}

output "instances_extra_sg_id" {
    value = module.tfe_instances_extra_sg.sg_id
}
