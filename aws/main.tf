# multi-cloud-gitops-platform/argocd/aws/main.tf

# Install ArgoCD using Helm
resource "helm_release" "argocd" {
  name = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart = "argo-cd"
  namespace = "argocd"
  create_namespace = true
  version = "5.51.4"

  values = [
    <<-YAML
    server:
        service:
            type: LoadBalancer
        configs:
            params:
                server.insecure: true
    YAML
  ]
  depends_on = [data.aws_eks_cluster.this, data.aws_eks_cluster_auth.this]
}


# Password retrieval
resource "null_resource" "get_argocd_password" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<-EOT
        echo "Waiting for ArgoCD secret to be created..."
        sleep 30 # Give Kubernetes a moment to create the secret
        kubectl -n argocd get secret argcd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > argocd-password.txt
        echo "Password saved to argocd-password.txt"
    EOT
  }

  # Triggers to re-run this provisioner if the Helm release is updated
  triggers = {
    helm_release = helm_release.argocd.id
  }
}

# WHAT IF THE BELOW DOES NOT WORK.....??????
# DO THIS ON YOUR CLI
# 1. aws eks update-kubeconfig --region eu-west-2 --name ken-eks-cluster
# 2. kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# 3. kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d


# Output the ArgoCD server URL (if LoadBalancer is used)
output "argocd_server_url" {
  description = "Run this command to get the ArgoCD server LoadBalancer URL"
  value = "kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
  depends_on = [helm_release.argocd]
}


# Output the initial admin password created by the null_resource
output "argocd_initial_secret" {
  description = "Initial ArgoCD admin password (saved locally to argocd-password.txt)"
  value = fileexists("${path.module}/argocd-password.txt") ? file("${path.module}/argocd-password.txt") : "Password not yet available. Run 'cat argocd-password' after apply finishes."
  depends_on = [null_resource.get_argocd_password]
}