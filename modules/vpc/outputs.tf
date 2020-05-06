output "vpc_id" {
  value = aws_vpc.tfe_vpc.id
}

output "public_subnets" {
  value = aws_subnet.tfe_public.*.cidr_block
}

output "public_subnets_id" {
  value = aws_subnet.tfe_public.*.id
}

output "private_subnets" {
  value = aws_subnet.tfe_private.*.cidr_block
}

output "private_subnets_id" {
  value = aws_subnet.tfe_private.*.id
}

output "database_subnets" {
  value = aws_subnet.tfe_database.*.cidr_block
}

output "database_subnets_id" {
  value = aws_subnet.tfe_database.*.id
}

output "db_subnet_group" {
  value = aws_db_subnet_group.tfe_db_subnet_group.*.id
}

output "az" {
  value = var.az
}