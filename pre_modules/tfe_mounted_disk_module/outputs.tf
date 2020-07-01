output "public_ip" {
  value = aws_instance.tfe_instance.public_ip
}

output "public_dns" {
  value = aws_instance.tfe_instance.public_dns
}

output "lb_fqdn" {
  value = aws_route53_record.flamarion.fqdn
}

output "instance_id" {
  value = aws_instance.tfe_instance.id
}

output "sg_id" {
  value = module.tfe_sg.sg_id
}
