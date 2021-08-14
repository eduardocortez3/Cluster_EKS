
################ IAM role - EKS ################
resource "aws_iam_role" "eks_role" {
  name = var.role.eks_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_policy_attachment" "eks_role-AmazonEKSClusterPolicy" {
  name       = "attachment01"
  roles      = ["${aws_iam_role.eks_role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  depends_on = [
    aws_iam_role.eks_role
  ]
}
resource "aws_iam_policy_attachment" "eks_role-AmazonEKSServicePolicy" {
  name       = "attachment02"
  roles      = ["${aws_iam_role.eks_role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  depends_on = [
    aws_iam_role.eks_role
  ]
} 

################ IAM - node group ################
resource "aws_iam_role" "eks_role_nodes" {
  name = var.role.node_role_name
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}
resource "aws_iam_role_policy_attachment" "eks_role_nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_role_nodes.name
}
resource "aws_iam_role_policy_attachment" "eks_role_nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_role_nodes.name
}
resource "aws_iam_role_policy_attachment" "eks_role_nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_role_nodes.name
}