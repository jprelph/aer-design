output "clusterName" {
    value = var.cluster_name
}

output "primaryVpcId" {
    value = module.vpc.vpc_id
}

output "secondaryVpcId" {
    value = module.vpc_secondary.vpc_id
}

output "primaryAzs" {
    value = module.vpc.azs
}

output "secondaryAzs" {
    value = module.vpc_secondary.azs
}

output "primaryPrivateSubnets" {
    value = module.vpc.private_subnets
}

output "secondaryPrivateSubnets" {
    value = module.vpc_secondary.private_subnets
}

output "nodeIamRoleArn" {
    value = module.eks.node_iam_role_arn
}

output "nodeIamRoleName" {
    value = module.eks.node_iam_role_name
}

output "globalEndpoint" {
    value = aws_rds_global_cluster.events.endpoint
}

output "dbUser" {
    value = aws_rds_cluster.primary.master_username
}

output "dbPassword" {
    sensitive = true
    value = aws_rds_cluster.primary.master_password
}

output "dbName" {
   value = aws_rds_cluster.primary.database_name
}