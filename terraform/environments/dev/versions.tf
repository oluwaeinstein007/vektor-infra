terraform {
  required_version = ">= 1.9"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.6"
    }
  }

  # Local backend for dev — a single engineer's k3s box (INFRA-003 "k3s
  # dev"), no team-shared state needed. See environments/prod for the
  # shared backend.
}
