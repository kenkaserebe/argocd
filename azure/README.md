# ArgoCD on Azure (AKS)

This Terraform configuration deploys [ArgoCD](https://argo-cd.readthedocs.io/) on to an exisiting Azure Kubernetes Service (AKS) cluster using the official Helm chart. It configures ArgoCD with a LoadBalancer service for external access and retrieves the initial admin password.

## Purpose

ArgoCD is a GitOps continuous delivery tool for Kubernetes. This module automates its installation on AKS, making it ready to manage application deployments via Git repositories.

## Features

- Installs ArgoCD using the Helm chart from `https://argoproj.github.io/argo-helm`
- Creates a dedicated `argocd` namespace
- Configures the ArgoCD server service as a **LoadBalancer** (accessible via a public IP)
- Enables insecure HTTP access (for simplicity - see security note below)
- Retrieves the initial admin password and save it to a local file (`argocd-password.txt)
- Provides output commands to get the LoadBalancer URL and password

## Prerequisites

- **Existing AKS cluster** - you must have a running AKS cluster. You can create one usng the [bootstrap/azure](../bootstrap/azure) module or any other method.
- **Terraform** (v1.14+)
- **kubectl** (optional, for manual fallback)
- **Azure CLI** - authenticated and with access to the AKS cluster
- **Helm** (not required locally; the Terraform Helm provider handles everything)

## Required Azure permissions

The Terraform provider needs permissions to:
- Read the AKS cluster details (`Microsoft.ContainerService/managedClusters/read`)
- Use the cluster's admin credentials (usually via `az aks get-credentials`)

These permissions are typically granted by roles like `Azure Kubernetes Service Cluster User Role` or `Contributer` on the AKS cluster.


## Usage

### 1. Clone the repository

bash
git clone https://github.com/kenkaserebe/bootstrap.git
cd bootstrap/argocd/azure

### 2. Configure variables

Create a terraform.tfvars file:

hcl
cluster_name            = "my-aks-cluster"
resource_group_name     = "my-aks-resource-group"

### 3. Initialize and apply

bash
terraform init
terraform plan
terraform apply

### 4. Access ArgoCD

After apply finishes, Terraform outputs:

argocd_server_command - command to retrieve the LoadBalancer hostname
argoce_initial_secret - the initial admin password (also saved to argocd-password.txt)

Run the command to get the URL:

bash
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

Then open http://<hostname> in your browser. Log in with:

Username: admin
Password: (value from argocd-password.txt or the output)


#### Variables

Name                Description                                     Type        Required
cluster_name        Name of the existing AKS cluster                string      yes
resource_group_name Resource group where the AKS cluster resides    string      yes

#### Outputs

Name                       Description
argocd_server_command      Command to get the LoadBalancer hostname of the ArgoCD server
argocd_initial_secret      The initial admin password (saved locally to 
                           argocd-password.txt as well)


##### Notes & Known Issues

###### Security Warning

The configuration sets server.insecure: true. This enables plain HTTP access. For production, you should:
    - Remove server.insecure: true and configure TLS (e.g., using cert-manager + Let's Encrypt)
    - Or use an Ingress controller with HTTPS termination


###### Password Retrieval Fallback

If the null_resource fails to retrieve the password (e.g., due to timing or network issues), use the manual commands shown in the comments:

bash
# 1. Update kubeconfig for your AKS cluster
az aks update-kubeconfig --name my-aks-cluster --resource-group my-aks-resource-group

# 2. Get the LoadBalancer hostname
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# 3. Get the initial admin password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 4. Generate a new password
# If you need to reset the admin password, go to https://www.browserling.com/tools/bcrypt and
# generate a new hash. Then, in the terminal connected to the cluster's kubectl, do:
kubectl -n argocd patch secret argocd-secret -p '{"stringData": { "admin.password": "<generated-hash>", "admin.passwordMtime": "'$(date +%FT%T%Z)'"}}'


###### Provider Configuration

The Terraform configuration:

- Uses the azurerm provider to fetch AKS cluster data (no need to manage the cluster itself)
- Configures the kubernetes and helm providers using the AKS cluster's admin credentials (kubeconfig)

Make sure your Azure CLI is logged in (az login) before running Terraform, as the azurerm provider will use those credentials by default.


##### Cleanup

To remove ArgoCD from the AKS cluster:

bash
terraform destroy


This will delete the Helm release and the argocd namespace (including all resources created by the chart). The local argocd-password.txt file will remain - delete it manually if desired.


##### License

[Specify your license, e.g., MIT]