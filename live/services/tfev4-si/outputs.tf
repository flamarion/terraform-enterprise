output "instance_id" {
  value = module.tfe_instance.*.intance_id
}

output "public_ip" {
  value = module.tfe_instance.*.public_ip
}

output "public_dns" {
  value = module.tfe_instance.*.public_dns
}