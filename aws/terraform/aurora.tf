# Primary Aurora Cluster

resource "aws_rds_global_cluster" "events" {
  global_cluster_identifier = "global-events"
  engine                    = "aurora-mysql"
  engine_version            = "8.0.mysql_aurora.3.09.0"
  database_name             = "events_db"
}

resource "aws_db_subnet_group" "events_primary" {
  provider   = aws.primary
  name       = "events"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_rds_cluster" "primary" {
  provider                  = aws.primary
  engine                    = aws_rds_global_cluster.events.engine
  engine_version            = aws_rds_global_cluster.events.engine_version
  engine_mode               = "provisioned"
  cluster_identifier        = "events-primary-cluster"
  manage_master_user_password = true
  master_username           = "events_user"
  database_name             = "events_db"
  global_cluster_identifier = aws_rds_global_cluster.events.id
  db_subnet_group_name      = aws_db_subnet_group.events_primary.name
  skip_final_snapshot       = true
  serverlessv2_scaling_configuration {
    max_capacity             = 2.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 3600
  }
}

resource "aws_rds_cluster_instance" "primary" {
  provider             = aws.primary
  engine               = aws_rds_global_cluster.events.engine
  engine_version       = aws_rds_global_cluster.events.engine_version
  identifier           = "events-primary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.primary.id
  instance_class       = "db.serverless"
  db_subnet_group_name = aws_db_subnet_group.events_primary.name
}

# Secondary Aurora Cluster

resource "aws_db_subnet_group" "events_secondary" {
  provider   = aws.secondary
  name       = "events"
  subnet_ids = module.vpc_secondary.private_subnets
}

resource "aws_rds_cluster" "secondary" {
  provider                  = aws.secondary
  engine                    = aws_rds_global_cluster.events.engine
  engine_version            = aws_rds_global_cluster.events.engine_version
  engine_mode               = "provisioned"
  cluster_identifier        = "events-secondary-cluster"
  global_cluster_identifier = aws_rds_global_cluster.events.id
  db_subnet_group_name      = aws_db_subnet_group.events_secondary.name
  skip_final_snapshot       = true
  serverlessv2_scaling_configuration {
    max_capacity             = 2.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 3600
  }
  lifecycle {
    ignore_changes = [
      replication_source_identifier
    ]
  }
  depends_on = [
    aws_rds_cluster_instance.primary
  ]
}

resource "aws_rds_cluster_instance" "secondary" {
  provider             = aws.secondary
  engine               = aws_rds_global_cluster.events.engine
  engine_version       = aws_rds_global_cluster.events.engine_version
  identifier           = "events-secondary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.secondary.id
  instance_class       = "db.serverless"
  db_subnet_group_name = aws_db_subnet_group.events_secondary.name
}