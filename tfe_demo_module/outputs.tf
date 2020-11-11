output "public_ip" {
  value = module.tfe_instance.public_ip
}

output "public_dns" {
  value = module.tfe_instance.public_dns
}

output "lb_fqdn" {
  value = aws_route53_record.flamarion.fqdn
}

output "instance_id" {
  value = module.tfe_instance.instance_id
}

output "sg_id" {
  value = module.sg.sg_id
}
