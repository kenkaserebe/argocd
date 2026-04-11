# ArgoCD on AWS (EKS)

This Terraform configuration deploys [ArgoCD](https://argo-cd.readthedocs.io/) on to an existing Amazon EKS cluster using the official Helm chart. It configures ArgoCD with a LoadBalancer service for external access, retrieves the initial admin password, and stores the Terraform state remotely in an S3 bucket.

## Purpose

ArgoCD is a GitOps continuous delivery tool for Kubernetes. This module automates its installation on EKS, making it ready to manage application deployments via Git repositories.

## Features

- Installs ArgoCD using the Helm chart from `https://argoproj.github.io/argo-helm`
- Creates a dedicated `argocd` namespace
- Configures the ArgoCD server service as a **LoadBalancer** (accessible via a public hostname)
- Enables insecure HTTP access (for simplicity - see security note below)
- Retrieves the initial admin password and saves it to a local file (`argocd-password.txt`)
- Provides output commands to get the LoadBalancer hostname and password
- **Remote state** - Terraform state is stored in an S3 bucket (must exist before use)

## Prerequisites

- **Existing EKS cluster** - you must have a running EKS cluster. You can create one using the [bootstrap/aws](../bootstrap/aws) module or any other method.
- **Terraform** (v1.14+)
- **kubectl** (optional, for manual fallback)
- **AWS CLI** - configured with credentials that have access to:
    - The EKS cluster (`eks:DescribeCluster`)
    - The S3 bucket used for Terraform state (`s3:GetObject`, `s3:PutObject`, etc.)
- **Helm** (not required locally; the Terraform Helm provider handles everything)

## Required AWS Permissions

The Terraform providers need permissions to:
- Read EKS cluster details (`eks:DescribeCluster`)
- Generate a token for Kubernetes authentication (`eks:GetToken)
- Read/write Terraform state in the S3 bucket (if using the remote backend)

These permissions are typically granted by roles like `AmazonEKSClusterPolicy` and custom S3 bucket policies.

## Usage

### 1. Clone the repository

bash
git clone https://github.com/kenkaserebe/bootstrap.git
cd bootstrap/argocd/aws


### 2. Configure the remote backend (optional but recommended)

The backend.tf file already configures an S3 backend with a hardcoded bucket name:

hcl
terraform {
    backend "s3" {
        bucket          = "ken-aws-multi-cloud-tfstate-unique-bucket"
        key             = "argocd/terraform.tfstate"
        region          = "eu-west-2"
        encrypt         = true
        use_lockfile    = true
    }
}

Before using this configuration, ensure that:
- The S3 bucket ken-aws-multi-cloud-tfstate-unique-bucket exists in eu-west-2.
- You have write permissions to that bucket.

If you need to use a different bucket, you can:
- Edit backend.tf directly, or
- Use -backend-config during terraform init:

bash
terraform init -backend-config="bucket=your-unique-bucket-name" \
               -backend-config="region=your-region"

Important: The bucket should have been created by the bootstrap/aws module. It must have versioning and encryption enabled.


### 3. Configure variables

Create a terraform.tfvars file:

hcl
cluster_name = "my-eks-cluster"


### 4. Initialize and apply

bash
terraform init
terraform plan
terraform apply


### 5. Access ArgoCD

After apply finishes, Terraform outputs:
- argocd_server_url - command to retrieve the LoadBalancer hostname
- argocd_initial_secret - the initial admin password (also saved to argocd-password.txt)

Run the command to get the URL:

bash
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'


Then open http://<hostname> in your browser. Log in with:
- Username: admin
- Password: (value from argocd-password.txt or the output)


#### Variables

Name            Description                                 Type        Required
cluster_name    Name of the existing EKS cluster            string      yes


#### Outputs

Name                    Description
argocd_server_url       Command to get the LoadBalancer hostname of the ArgoCD server
argocd_initial_secret   The initial admin password (saved locally to argocd-password.txt as well)


#### Notes & Known Issues

##### Security Warning

The configuration sets server.insecure: true. This enables plain HTTP access. For production, you should:
- Remove server.insecure: true and configure TLS (e.g., using cert-manager + Let's Encrypt)
- Or use an Ingress controller with HTTPS termination


##### Password Retrieval Fallback

If the null_resource fails to retrieve the password (e.g., due to timing or network issues), use the manual commands shown in the comments:

bash
# 1. Update kubeconfig for your EKS cluster
aws eks update-kubeconfig --region eu-west-2 --name my-eks-cluster

# 2. Get the LoadBalancer hostname
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# 3. Get the initial admin password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 4. Generate a new password
# If you need to reset the admin password, go to https://www.browserling.com/tools/bcrypt and
# generate a new hash. Then, in the terminal connected to the cluster's kubectl, do:
kubectl -n argocd patch secret argocd-secret -p '{"stringData": { "admin.password": "<generated-hash>", "admin.passwordMtime": "'$(date +%FT%T%Z)'"}}'


##### Remote State Dependencies

The S3 backend bucket must exist before running terraform init. Use the bootstrap/aws module to create it if it doesn't exist.


##### Cleanup

To remove ArgoCD from the EKS cluster:

bash
terraform destroy

This will delete the Helm release and the argocd namespace (including all resources created by the chart). The local argocd-password.txt file and the remote Terraform state in S3 will remain - delete them manually if desired.


##### License

[Specify your license, e.g., MIT]