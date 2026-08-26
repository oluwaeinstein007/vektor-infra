# Dev environment — one k3s node, everything downsized. Mirrors prod's
# module composition exactly (same modules, different variable values) so
# there's no "works in dev, structurally different in prod" drift.

# The TS backend-service namespace itself — every vektor-backend service
# (SVC-001 etc.) deploys here once its own roadmap task scaffolds it. Owned
# directly by the environment root, not a module, since it's a single
# resource other modules only ever reference by name.
resource "kubernetes_namespace_v1" "vektor_backend" {
  metadata {
    name = "vektor-backend"
    labels = {
      "vektor.io/tier" = "backend"
    }
  }
}

# The frontend namespace (vektor-web: apps/web, and eventually field-pwa) —
# split out from the above when vektor-platform became vektor-backend +
# vektor-web (§9.2).
resource "kubernetes_namespace_v1" "vektor_web" {
  metadata {
    name = "vektor-web"
    labels = {
      "vektor.io/tier" = "web"
    }
  }
}

module "observability" {
  source = "../../modules/observability"

  prometheus_retention = "7d"
  loki_storage_size    = "20Gi"
}

module "vektor_ml_enclave" {
  source = "../../modules/vektor-ml-enclave"

  observability_namespace = module.observability.namespace
  resource_quota = {
    cpu    = "8"
    memory = "32Gi"
    gpu    = "1"
  }
}

module "kafka" {
  source = "../../modules/kafka"

  broker_count  = 1
  storage_size  = "20Gi"
  storage_class = "local-path" # k3s default
}

module "data_stores" {
  source = "../../modules/data-stores"

  minio_storage_size   = "50Gi"
  minio_storage_class  = "local-path"
  qdrant_replica_count = 1
  qdrant_storage_size  = "10Gi"
  redis_shard_count    = 3
}

module "vault" {
  source = "../../modules/vault"

  ha_replicas     = 1
  kubernetes_host = "https://kubernetes.default.svc"
}

module "gateway" {
  source = "../../modules/gateway"

  kong_replica_count = 1
}

module "istio" {
  source = "../../modules/istio"

  # istio module labels these namespaces for sidecar injection — they must
  # exist first.
  depends_on = [kubernetes_namespace_v1.vektor_backend, kubernetes_namespace_v1.vektor_web, module.gateway]
}
