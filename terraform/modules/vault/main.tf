# INFRA-010 — HashiCorp Vault + secret rotation.
#
# NOTE on scope: Vault's initial init/unseal is a deliberate manual key
# ceremony (or cloud-KMS auto-unseal configured once, out-of-band) — that
# step is intentionally NOT automated here. Automating root-key generation
# inside Terraform state would defeat the point of the ceremony. Everything
# below assumes a running, unsealed Vault and configures it for the
# "secret rotation" half of INFRA-010: short-lived credentials issued via
# Kubernetes auth, not static long-lived secrets checked into anything.

resource "kubernetes_namespace_v1" "vault" {
  metadata {
    name = var.namespace
    labels = {
      "vektor.io/tier" = "secrets"
    }
  }
}

resource "helm_release" "vault" {
  name       = "vektor-vault"
  namespace  = kubernetes_namespace_v1.vault.metadata[0].name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.29.1"

  set {
    name  = "server.ha.enabled"
    value = "true"
  }
  set {
    name  = "server.ha.replicas"
    value = var.ha_replicas
  }
  set {
    name  = "server.ha.raft.enabled"
    value = "true"
  }
  set {
    name  = "server.auditStorage.enabled"
    value = "true"
  }
}

# Kubernetes auth backend: services authenticate with their K8s
# ServiceAccount token and get a short-lived Vault token back — this is the
# "rotation" mechanism. No service ever holds a Vault token that outlives
# its pod.
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_host
  disable_iss_validation = false
}

resource "vault_policy" "policies" {
  for_each = var.policy_files
  name     = each.key
  policy   = file(each.value)
}

# vektor-platform services (any pod whose ServiceAccount lives in the
# vektor-platform namespace) get the vektor-platform policy; vektor-ml
# enclave pods get the narrower vektor-ml policy. Neither can request the
# other's role — this is the Vault-side half of §14.2's isolation.
resource "vault_kubernetes_auth_backend_role" "vektor_platform" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vektor-platform"
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = ["vektor-platform"]
  token_policies                   = [vault_policy.policies["vektor-platform"].name]
  token_ttl                        = 900
  token_max_ttl                    = 3600
}

resource "vault_kubernetes_auth_backend_role" "vektor_ml" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vektor-ml"
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = ["vektor-ml-enclave"]
  token_policies                   = [vault_policy.policies["vektor-ml"].name]
  token_ttl                        = 900
  token_max_ttl                    = 3600
}
