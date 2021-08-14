variable "vpc" {
    type = map
    description = "Nome do Stack que aparece no Cloudformation Stack"
    default = {
       "vpc_name" = "VPC-EKS"
   }
}

variable "role" {
    type = map
    description = "Nome Role que será criada no IAM para o cluster e nodes"
    default = {
        "eks_name"       = "eks-role"
        "node_role_name" = "eks-node-group"
    }
}

variable "eks" {
  type = map
  description = "Nome e chave de acesso ao cluster EKS"
  default = {
        "name"    = "eks01"
        "ssh_key" = "terraform-aws"
  }
}

variable "nodegroup" {
  type = map
  description = "Características do Node Group"
  default = {
        "name"    = "nodegroup_eks"
        "ami"     = "AL2_x86_64"
        "type"    = "t3.small"
        "min"     = "1"
        "max"     = "6"
        "desired" = "4"
        "disk"    = "20"
  }
}
