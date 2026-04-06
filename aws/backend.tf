# multi-cloud-gitops-platform/argocd/aws/backend.tf

terraform {
  backend "s3" {
    bucket          = "ken-aws-multi-cloud-tfstate-unique-bucket"
    key             = "argocd/terraform.tfstate"
    region          = "eu-west-2"
    encrypt         = true
    use_lockfile    = true
  }
}


# use terraform init -backend-config=backend.hcl