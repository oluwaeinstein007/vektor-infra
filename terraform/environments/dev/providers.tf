variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kube_context" {
  description = "kubectl context for the local k3s dev cluster bootstrapped by scripts/bootstrap-k3s-dev.sh."
  type        = string
  default     = "k3s-dev"
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

provider "vault" {
  address = "http://127.0.0.1:8200" # port-forwarded from the in-cluster vektor-vault service
}
