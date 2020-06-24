output "vpc_id" {
  value = aws_vpc.tfe_vpc.id
}

output "subnets" {
  value = aws_subnet.tfe_public.*.cidr_block
}

output "subnet_ids" {
  value = aws_subnet.tfe_public.*.id
}

output "private_subnets" {
  value = aws_subnet.tfe_private.*.cidr_block
}

output "private_subnet_ids" {
  value = aws_subnet.tfe_private.*.id
}

output "db_subnet_group" {
  value = aws_db_subnet_group.db.id
}

output "az" {
  value = data.aws_availability_zones.az.names
}