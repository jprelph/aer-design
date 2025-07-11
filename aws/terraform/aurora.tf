resource "aws_rds_global_cluster" "example" {
  global_cluster_identifier = "global-test"
  engine                    = "aurora"
  engine_version            = "5.6.mysql_aurora.1.22.2"
  database_name             = "example_db"
}

resource "aws_rds_cluster" "primary" {
  provider                  = aws.primary
  engine                    = aws_rds_global_cluster.example.engine
  engine_version            = aws_rds_global_cluster.example.engine_version
  cluster_identifier        = "test-primary-cluster"
  master_username           = "username"
  master_password           = "somepass123"
  database_name             = "example_db"
  global_cluster_identifier = aws_rds_global_cluster.example.id
  db_subnet_group_name      = "default"
}

resource "aws_rds_cluster_instance" "primary" {
  provider             = aws.primary
  engine               = aws_rds_global_cluster.example.engine
  engine_version       = aws_rds_global_cluster.example.engine_version
  identifier           = "test-primary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.primary.id
  instance_class       = "db.r4.large"
  db_subnet_group_name = "default"
}

resource "aws_rds_cluster" "secondary" {
  provider                  = aws.secondary
  engine                    = aws_rds_global_cluster.example.engine
  engine_version            = aws_rds_global_cluster.example.engine_version
  cluster_identifier        = "test-secondary-cluster"
  global_cluster_identifier = aws_rds_global_cluster.example.id
  db_subnet_group_name      = "default"

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
  engine               = aws_rds_global_cluster.example.engine
  engine_version       = aws_rds_global_cluster.example.engine_version
  identifier           = "test-secondary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.secondary.id
  instance_class       = "db.r4.large"
  db_subnet_group_name = "default"
}
