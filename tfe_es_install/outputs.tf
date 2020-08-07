# LB
output "lb_sg_id" {
    value = module.tfe_es.lb_sg_id
}

output "db_sg_id" {
    value = module.tfe_es.db_sg_id
}

output "instances_sg_id" {
    value = module.tfe_es.instances_sg_id
}

output "instances_extra_sg_id" {
    value = module.tfe_es.instances_extra_sg_id
}

# DB
output "db_cluster_endpoint" {
    value = module.tfe_es.db_cluster_endpoint
}

output "db_cluster_port" {
    value = module.tfe_es.db_cluster_port
}

output "db_cluster_name" {
    value = module.tfe_es.db_cluster_name
}

output "db_cluster_user" {
    value = module.tfe_es.db_cluster_user
}

output "db_cluster_pass" {
    value = module.tfe_es.db_cluster_pass
}