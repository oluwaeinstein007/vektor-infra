variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kube_context" {
  type    = string
  default = "vektor-prod"
}

variable "vault_addr" {
  description = "Vault must be reachable at a stable address before this environment's first apply — see terraform/modules/vault's note on the manual init/unseal ceremony."
  type        = string
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
  address = var.vault_addr
}
