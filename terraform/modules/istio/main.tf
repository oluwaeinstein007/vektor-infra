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
