# DB Cluster
resource "aws_rds_cluster" "db_cluster" {
  engine                 = var.db_engine
  cluster_identifier     = var.cluster_identifier
  database_name          = var.db_name
  master_password        = var.db_pass
  master_username        = var.db_user
  skip_final_snapshot    = var.skip_final_snapshot
  availability_zones     = var.az_list
  vpc_security_group_ids = var.sg_id_list
  apply_immediately      = var.apply_immediately
  db_subnet_group_name   = var.db_subnet_group
  tags                   = var.db_tags
}

resource "aws_rds_cluster_instance" "db_instance" {
  identifier           = var.instance_identifier
  cluster_identifier   = aws_rds_cluster.db_cluster.id
  engine               = var.db_engine
  instance_class       = var.instance_type
  publicly_accessible  = var.public
  db_subnet_group_name = var.db_subnet_group
  apply_immediately    = var.apply_immediately
}
