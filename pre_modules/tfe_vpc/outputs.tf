output "vpc_id" {
  value = module.tfe_vpc.vpc_id
}

output "public_subnets" {
  value = module.tfe_vpc.public_subnets
}

output "public_subnets_id" {
  value = module.tfe_vpc.public_subnets_id
}

output "private_subnets" {
  value = module.tfe_vpc.private_subnets
}

output "private_subnets_id" {
  value = module.tfe_vpc.private_subnets_id
}

output "database_subnets" {
  value = module.tfe_vpc.database_subnets
}

output "database_subnets_id" {
  value = module.tfe_vpc.database_subnets_id
}

output "db_subnet_group" {
  value = module.tfe_vpc.db_subnet_group
}

output "az" {
  value = module.tfe_vpc.az
}