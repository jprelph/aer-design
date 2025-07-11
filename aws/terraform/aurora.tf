resource "aws_rds_global_cluster" "events" {
  global_cluster_identifier = "global-events"
  engine                    = "aurora"
  engine_version            = "8.0.40.mysql_aurora.3.09.0"
  database_name             = "events_db"
}

resource "aws_rds_cluster" "primary" {
  provider                  = aws.primary
  engine                    = aws_rds_global_cluster.events.engine
  engine_version            = aws_rds_global_cluster.events.engine_version
  cluster_identifier        = "events-primary-cluster"
  master_username           = "username"
  master_password           = "somepass123"
  database_name             = "events_db"
  global_cluster_identifier = aws_rds_global_cluster.events.id
  db_subnet_group_name      = "default"
}

resource "aws_rds_cluster_instance" "primary" {
  provider             = aws.primary
  engine               = aws_rds_global_cluster.events.engine
  engine_version       = aws_rds_global_cluster.events.engine_version
  identifier           = "events-primary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.primary.id
  instance_class       = "db.t4g.small"
  db_subnet_group_name = "default"
}

resource "aws_rds_cluster" "secondary" {
  provider                  = aws.secondary
  engine                    = aws_rds_global_cluster.events.engine
  engine_version            = aws_rds_global_cluster.events.engine_version
  cluster_identifier        = "events-secondary-cluster"
  global_cluster_identifier = aws_rds_global_cluster.events.id
  db_subnet_group_name      = "default"
  enable_global_write_forwarding = true

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
  identifier           = "test-secondary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.secondary.id
  instance_class       = "db.t4g.small"
  db_subnet_group_name = "default"
}
