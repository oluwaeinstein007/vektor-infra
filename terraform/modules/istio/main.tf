# SEC-001 — Istio mTLS enforcement across all TS services.

resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.chart_version
}

resource "helm_release" "istiod" {
  name       = "istiod"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.chart_version

  depends_on = [helm_release.istio_base]
}

resource "kubernetes_labels" "mesh_injection" {
  for_each    = toset(var.mesh_namespaces)
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = each.value
  }
  labels = {
    "istio-injection" = "enabled"
  }
}

# Mesh-wide STRICT mTLS — plaintext traffic between any two mesh sidecars is
# rejected, not merely upgraded opportunistically. This is what actually
# closes the "Unauthorized data access" threat-model row (§14.1) at the
# network layer, on top of RBAC.
#
# NOTE: kubernetes_manifest requires the PeerAuthentication CRD to already
# exist in the cluster at plan time (istiod must be installed first). In
# practice this means `terraform apply -target=helm_release.istiod` once,
# then a normal `terraform apply` — a documented Terraform+CRD limitation,
# not something specific to this repo.
resource "kubernetes_manifest" "mesh_peer_auth" {
  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "PeerAuthentication"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace_v1.istio_system.metadata[0].name
    }
    spec = {
      mtls = {
        mode = "STRICT"
      }
    }
  }
  depends_on = [helm_release.istiod]
}

# SEC-002 audit note (2026-08-26): this module deliberately stops at STRICT
# mTLS (L4 transport identity — "is this sidecar-to-sidecar traffic
# authenticated") and does NOT add AuthorizationPolicy resources (L7 —
# "is this specific caller allowed to call this specific service"). Every
# other network-boundary module in this repo (vektor-ml-enclave) pairs its
# default-deny with concrete named allow-rules; doing the same here would
# require matching on each workload's Kubernetes ServiceAccount identity
# (`source.principals: ["cluster.local/ns/<ns>/sa/<name>"]`), and no
# ServiceAccount-per-service naming convention exists yet anywhere in this
# repo — actual Deployment manifests (and therefore ServiceAccounts) are
# expected to land in vektor-platform's own repo per-service, the same
# "this repo is bootstrap/ops tooling, application manifests land next to
# the application" split vektor-edge's README documents for its own
# placeholder image tags. Writing AuthorizationPolicy rules against guessed
# ServiceAccount names now would be unverifiable config that might not even
# match what gets deployed — worse than no policy, since it reads as done
# when it isn't. A default-deny AuthorizationPolicy specifically must NOT
# be added without its matching allow-rules in the same change: on a real
# cluster it would immediately block every request into vektor-platform,
# including Kong's own ingress traffic.
#
# The concrete call graph, established from actually reading
# vektor-platform's source (not guessed) so whoever adds this doesn't have
# to re-derive it:
#   - coa-svc -> audit-svc      (POST /api/v1/audit, services/coa-svc/src/audit/client.ts)
#   - coa-svc -> fusion-svc     (GET no-strike-zones, services/coa-svc/src/context/fetchNoStrikeZones.ts)
#   - vektor-gateway (Kong) -> every public-facing vektor-platform service (REST ingress)
# fusion-svc -> alert-svc is NOT an HTTP call (BullMQ over Redis), so it has
# no Istio-mesh AuthorizationPolicy analog.
