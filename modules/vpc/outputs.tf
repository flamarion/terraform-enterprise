output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnets" {
  value = aws_subnet.public.*.cidr_block
}

output "public_subnets_id" {
  value = aws_subnet.public.*.id
}

output "private_subnets" {
  value = aws_subnet.private.*.cidr_block
}

output "private_subnets_id" {
  value = aws_subnet.private.*.id
}

output "database_subnets" {
  value = aws_subnet.database.*.cidr_block
}

output "database_subnets_id" {
  value = aws_subnet.database.*.id
}

output "db_subnet_group" {
  value = aws_db_subnet_group.db_subnet_group.*.id
}

output "az" {
  value = var.az
}