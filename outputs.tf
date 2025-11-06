output "kubeconfig_path" {
  description = "Path to the kubeconfig file for the k3s cluster"
  value       = abspath("${path.module}/kubeconfig")
}

output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = "https://${var.server_ip}:${var.server_port}"
}

output "kubectl_config_command" {
  description = "Command to configure kubectl to use this cluster"
  value       = "export KUBECONFIG=${abspath("${path.module}/kubeconfig")}"
}

output "cluster_info" {
  description = "Instructions for using the cluster"
  value       = <<-EOT
    k3s cluster has been successfully installed!

    To use this cluster, run:
      export KUBECONFIG=${abspath("${path.module}/kubeconfig")}
      kubectl get nodes

    Available applications:

    1. Deploy Langflow:
      cd ../langflow-infra
      terraform init
      terraform apply -var="kubeconfig_path=${abspath("${path.module}/kubeconfig")}"

    2. Deploy Jenkins CI/CD:
      ./deploy-jenkins.sh
      # Or: make jenkins-deploy

    To uninstall k3s:
      terraform destroy
  EOT
}

output "jenkins_enabled" {
  description = "Whether Jenkins is enabled"
  value       = var.jenkins_enabled
}

output "jenkins_namespace" {
  description = "Jenkins namespace"
  value       = var.jenkins_enabled ? "jenkins" : "not deployed"
}
