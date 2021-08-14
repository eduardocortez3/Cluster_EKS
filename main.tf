terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
provider "aws" {
  region = "us-east-2"
}

################ DEPLOY DO VPC ################
resource "aws_cloudformation_stack" "vpc" {
  name = var.vpc.vpc_name
  parameters = {
  }
    template_body = file("${path.module}/amazon-eks-vpc-private-subnets.yaml")
}
data "aws_subnet_ids" "subnets_ids" {
  vpc_id = aws_cloudformation_stack.vpc.outputs.VpcId
  depends_on = [
    aws_cloudformation_stack.vpc,  
  ]
}
data "aws_subnet" "names_subnets" {
  for_each = data.aws_subnet_ids.subnets_ids.ids
  id       = each.value
  depends_on = [
    aws_cloudformation_stack.vpc,
    data.aws_subnet_ids.subnets_ids,
  ]
}

################ DEPLOY EKS ################
resource "aws_eks_cluster" "eks" {
  name     = var.eks.name
  enabled_cluster_log_types = ["api", "audit", "controllerManager", "scheduler"]
  role_arn = aws_iam_role.eks_role.arn
  version = "1.21"
 
  vpc_config {
    subnet_ids = data.aws_subnet_ids.subnets_ids.ids
  }
  depends_on = [
    aws_cloudformation_stack.vpc,
    aws_iam_role.eks_role,
    aws_iam_policy_attachment.eks_role-AmazonEKSClusterPolicy,
    aws_iam_policy_attachment.eks_role-AmazonEKSServicePolicy,
  ]
}
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "vpc-cni"
  depends_on = [
    aws_eks_cluster.eks    
  ]
}
resource "aws_eks_addon" "kubeproxy" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "kube-proxy"
  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_addon.vpc_cni
  ]
}
resource "aws_cloudwatch_log_group" "role_logging_eks" {
  name              = "/aws/eks/${var.eks.name}"
  retention_in_days = 7
}

################ DEPLOY NODES DO EKS ################
resource "aws_eks_node_group" "nodegroup_eks" {
  cluster_name    = var.eks.name
  node_group_name = var.nodegroup.name
  node_role_arn   = "${aws_iam_role.eks_role_nodes.arn}"
  subnet_ids      = "${data.aws_subnet_ids.subnets_ids.ids}"
  ami_type        = "${var.nodegroup.ami}"
  disk_size       = "${var.nodegroup.disk}"
  instance_types  = ["${var.nodegroup.type}"]

remote_access {
  ec2_ssh_key = var.eks.ssh_key
}
  scaling_config {
    desired_size = "${var.nodegroup.desired}"
    max_size     = "${var.nodegroup.max}"
    min_size     = "${var.nodegroup.min}"
  }
  depends_on = [
    aws_iam_role.eks_role,
    aws_cloudformation_stack.vpc,
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.eks_role_nodes-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_role_nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_role_nodes-AmazonEC2ContainerRegistryReadOnly,
    
  ]
}