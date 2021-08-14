output "Nome_cluster" {
  value = var.eks.name
}

output "subnets" {
  value = aws_cloudformation_stack.vpc.outputs.SubnetIds
}

## DATA VPC ##
output "subnet_cidr_blocks" {
  value = [for s in data.aws_subnet.names_subnets : s.cidr_block]
}

output "Subnet_IDS" {
  value = data.aws_subnet_ids.subnets_ids.ids
}

## EKS ##
output "endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks.certificate_authority[0].data
}