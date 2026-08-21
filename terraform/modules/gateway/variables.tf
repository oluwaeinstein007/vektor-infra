variable "namespace" {
  description = "Namespace for Kong + Keycloak — INFRA-007."
  type        = string
  default     = "vektor-gateway"
}

variable "keycloak_admin_password_secret" {
  description = "Name of a pre-existing K8s Secret (created out-of-band via Vault, never in tfvars) holding the Keycloak bootstrap admin password."
  type        = string
  default     = "keycloak-admin-credentials"
}

variable "kong_replica_count" {
  type    = number
  default = 3
}
