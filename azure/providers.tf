# multi-cloud-gitops-platform/argocd/azure/providers.tf


terraform {
  required_version = ">= 1.14"
  required_providers {
    azurerm = {
        source  = "hashicorp/azurerm"
        version = "~> 4.64.0"
    }
    kubernetes = {
        source  = "hashicorp/kubernetes"
        version = "~> 2.23"
    }
    helm = {
        source  = "hashicorp/helm"
        version = "~> 2.1.1"
    }
  }
}


# Data sources to fetch AKS cluster details
data "azurerm_kubernetes_cluster" "aks" {
  name                  = var.cluster_name
  resource_group_name   = var.resource_group_name
}


# Kubernetes provider configuration
provider "kubernetes" {
  host                      = data.azurerm_kubernetes_cluster.aks.kube_admin_config[0].host
  cluster_ca_certificate    = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  client_certificate        = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key                = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
}


# Helm provider (v2) - note the different syntax for kubernetes configuration than in (v3)
provider "helm" {
  kubernetes {
    host                      = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
    cluster_ca_certificate    = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
    client_certificate        = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key                = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)

  }
}


provider "azurerm" {
  features {}

  # Authentication is handled via Azure CLI, environment variables, or managed identity.
}