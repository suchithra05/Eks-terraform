variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
}

variable "instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}
