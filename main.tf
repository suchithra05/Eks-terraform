provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "voteapp_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "voteapp-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.voteapp_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "voteapp-public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.voteapp_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "voteapp-private-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.voteapp_vpc.id
  tags = {
    Name = "voteapp-igw"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.voteapp_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "voteapp-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_role" {
  name = "voteapp-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Cluster
resource "aws_eks_cluster" "voteapp_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public_subnet.id,
      aws_subnet.private_subnet.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_AmazonEKSClusterPolicy]
}

# IAM Role for Worker Nodes
resource "aws_iam_role" "node_role" {
  name = "voteapp-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Node Group
resource "aws_eks_node_group" "voteapp_nodes" {
  cluster_name    = aws_eks_cluster.voteapp_cluster.name
  node_group_name = "voteapp-node-group"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = [var.instance_type]

  depends_on = [
    aws_iam_role_policy_attachment.worker_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.worker_AmazonEKS_CNI_Policy
  ]
}
