output "public_access" {
  value = [
    module.tfe_md.public_ip,
    module.tfe_md.public_dns,
    module.tfe_md.lb_fqdn
  ]
}

output "instance_id" {
  value = module.tfe_md.instance_id
}

output "sg_id" {
  value = module.tfe_md.sg_id
}
