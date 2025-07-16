data "aws_availability_zones" "available_primary" {
  provider = aws.primary
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_availability_zones" "available_secondary" {
  provider = aws.secondary
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Primary VPC

module "vpc" {
  source   = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.primary
  }
  version  = "5.21.0"
  name = "events-vpc"
  cidr = var.primary_cidr
  azs  = slice(data.aws_availability_zones.available_primary.names, 0, 3)
  private_subnets = var.primary_vpc_private
  public_subnets  = var.primary_vpc_public
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "cluster" = "${var.cluster_name}-public"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "cluster" = "${var.cluster_name}-private"
  }
}

# Secondary VPC

module "vpc_secondary" {
  source   = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.secondary
  }
  version  = "5.21.0"
  name = "events-vpc"
  cidr = var.secondary_cidr
  azs  = slice(data.aws_availability_zones.available_secondary.names, 0, 3)
  private_subnets = var.secondary_vpc_private
  public_subnets  = var.secondary_vpc_public
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "cluster" = "${var.cluster_name}-public"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "cluster" = "${var.cluster_name}-private"
  }
}

# Create VPC Peering to support Aurora Global Writer Endpoint

data "aws_caller_identity" "peer" {
  provider = aws.secondary
}

resource "aws_vpc_peering_connection" "peer" {
  provider = aws.primary

  vpc_id        = module.vpc.vpc_id
  peer_vpc_id   = module.vpc_secondary.vpc_id
  peer_owner_id = data.aws_caller_identity.peer.account_id
  peer_region   = var.sec_region
  auto_accept   = false
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  provider = aws.secondary

  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection_options" "requester" {
  provider = aws.primary

  # As options can't be set until the connection has been accepted
  # create an explicit dependency on the accepter.
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  provider = aws.secondary

  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

#Update route tables to support peering

resource "aws_route" "secondary_peer" {
  provider                  = aws.primary
  count                     = length(module.vpc.private_route_table_ids)
  route_table_id            = tolist(module.vpc.private_route_table_ids)[count.index]
  destination_cidr_block    = var.secondary_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "primary_peer" {
  provider                  = aws.secondary
  count                     = length(module.vpc_secondary.private_route_table_ids)
  route_table_id            = tolist(module.vpc_secondary.private_route_table_ids)[count.index]
  destination_cidr_block    = var.primary_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}