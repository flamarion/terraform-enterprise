output "public_access" {
  value = aws_route53_record.alias_record.fqdn
}

output "instance_access" {
  value = module.tfe_instance.public_dns
}
