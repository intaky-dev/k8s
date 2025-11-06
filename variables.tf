variable "k3s_version" {
  description = "K3s version to install (e.g., v1.28.5+k3s1). Leave empty for latest stable."
  type        = string
  default     = ""
}

variable "k3s_install_options" {
  description = "Additional options for k3s installation"
  type        = string
  default     = "server --disable traefik"
  # --disable traefik: We'll use nginx-ingress from langflow-infra
  # Other useful options:
  # --disable servicelb: If you want to use MetalLB instead
  # --write-kubeconfig-mode 644: Make kubeconfig readable by all users
  # --cluster-cidr: Custom pod CIDR
  # --service-cidr: Custom service CIDR
}

variable "server_ip" {
  description = "Server IP address for kubeconfig (use 127.0.0.1 for local access)"
  type        = string
  default     = "127.0.0.1"
}

variable "server_port" {
  description = "K3s API server port"
  type        = number
  default     = 6443
}

variable "setup_local_storage" {
  description = "Setup and configure local-path storage class as default"
  type        = bool
  default     = true
}

variable "install_metrics_server" {
  description = "Install metrics-server for Horizontal Pod Autoscaling"
  type        = bool
  default     = true
}

variable "create_namespaces" {
  description = "List of namespaces to create"
  type        = list(string)
  default     = ["langflow"]
}

# Jenkins Configuration
variable "jenkins_enabled" {
  description = "Enable Jenkins deployment"
  type        = bool
  default     = false
}

variable "jenkins_version" {
  description = "Jenkins Helm chart version"
  type        = string
  default     = ""  # Latest version
}

variable "jenkins_storage_size" {
  description = "Storage size for Jenkins persistent volume"
  type        = string
  default     = "20Gi"
}

variable "jenkins_cpu_limit" {
  description = "CPU limit for Jenkins controller"
  type        = string
  default     = "2000m"
}

variable "jenkins_memory_limit" {
  description = "Memory limit for Jenkins controller"
  type        = string
  default     = "4Gi"
}

variable "jenkins_enable_docker" {
  description = "Enable Docker-in-Docker for Jenkins agents"
  type        = bool
  default     = true
}
