# INFRA-007 — Deploy Kong API Gateway + Keycloak.
# Kong is config-only per §9.5's layered diagram (OAuth2/OIDC · Rate
# Limiting · RBAC Enforcement) — it fronts every request into
# vektor-platform; Keycloak is the OIDC provider behind it (§10.2).
#
# The Keycloak admin password is deliberately NOT a Terraform variable with
# a default — it's read from a Secret that Vault (terraform/modules/vault)
# already wrote, so it never lands in tfvars, state diffs, or CI logs.

resource "kubernetes_namespace_v1" "gateway" {
  metadata {
    name = var.namespace
    labels = {
      "vektor.io/tier" = "gateway"
    }
  }
}

resource "helm_release" "keycloak" {
  name       = "vektor-keycloak"
  namespace  = kubernetes_namespace_v1.gateway.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "keycloak"
  version    = "24.3.1"

  set {
    name  = "auth.existingSecret"
    value = var.keycloak_admin_password_secret
  }
  set {
    name  = "postgresql.enabled"
    value = "false"
  }
  set {
    name  = "externalDatabase.host"
    value = "vektor-postgresql.vektor-data.svc.cluster.local"
  }
  set {
    name  = "replicaCount"
    value = "2"
  }
}

resource "helm_release" "kong" {
  name       = "vektor-kong"
  namespace  = kubernetes_namespace_v1.gateway.metadata[0].name
  repository = "https://charts.konghq.com"
  chart      = "kong"
  version    = "2.44.0"

  set {
    name  = "replicaCount"
    value = var.kong_replica_count
  }
  # DB-less: routes/plugins declared as CRDs (KongPlugin, KongIngress) that
  # live next to each service's manifest in vektor-platform's own repo,
  # rather than a stateful Kong Postgres this repo would have to own too.
  set {
    name  = "env.database"
    value = "off"
  }
  set {
    name  = "ingressController.enabled"
    value = "true"
  }

  depends_on = [helm_release.keycloak]
}
