output "public_access" {
  value = [
    aws_instance.tfe_instance.public_ip,
    aws_instance.tfe_instance.public_dns,
    aws_route53_record.flamarion.fqdn
  ]
}
