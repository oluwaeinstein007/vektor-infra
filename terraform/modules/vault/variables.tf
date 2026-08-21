variable "namespace" {
  description = "Namespace for the Vault cluster — INFRA-010."
  type        = string
  default     = "vektor-vault"
}

variable "ha_replicas" {
  type    = number
  default = 3
}

variable "kubernetes_host" {
  description = "K8s API server address Vault's kubernetes auth method validates service-account tokens against."
  type        = string
}

variable "policy_files" {
  description = "Map of Vault policy name -> path to its .hcl file (see ../../../vault/policies/)."
  type        = map(string)
  default = {
    "vektor-platform" = "../../../vault/policies/vektor-platform.hcl"
    "vektor-ml"       = "../../../vault/policies/vektor-ml.hcl"
  }
}
