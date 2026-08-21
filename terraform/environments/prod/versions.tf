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

  # State stored as a Secret in the cluster's own kube-system namespace,
  # rather than a named cloud object-storage backend — deliberate, since
  # §11 never commits VEKTOR to a specific hyperscaler (Cloud Core and
  # On-Prem DC run the identical stack on owned/colo hardware per §11.1-11.3,
  # not a named cloud vendor's managed services). A team that does deploy
  # onto a specific cloud can swap this block for s3/gcs/azurerm without
  # touching anything else in this repo.
  backend "kubernetes" {
    secret_suffix  = "vektor-infra-prod"
    namespace      = "kube-system"
    config_path    = "~/.kube/config"
    config_context = "vektor-prod"
  }
}
