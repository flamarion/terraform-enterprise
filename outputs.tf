output "public_access" {
  value = [
    module.tfe_demo.public_ip,
    module.tfe_demo.public_dns,
    module.tfe_demo.lb_fqdn
  ]
}

output "instance_id" {
  value = module.tfe_demo.instance_id
}

output "sg_id" {
  value = module.tfe_demo.sg_id
}
