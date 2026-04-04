# multi-cloud-gitops-platform/argocd/aws/variables.tf

variable "cluster_name" {
  description   = "Name of the EKS cluster"
  type          = string
}