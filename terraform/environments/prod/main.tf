# Prod (Cloud Core / On-Prem DC — §11.1 says these run "the same stack").
# Sizing here is pulled directly from §11.2/§11.3's hardware BOM, not
# invented — see the inline citations. Same module set as dev; only the
# variable values differ.

resource "kubernetes_namespace_v1" "vektor_platform" {
  metadata {
    name = "vektor-platform"
    labels = {
      "vektor.io/tier" = "platform"
    }
  }
}

module "observability" {
  source = "../../modules/observability"

  prometheus_retention = "90d"
  loki_storage_size    = "2Ti"
}

module "vektor_ml_enclave" {
  source = "../../modules/vektor-ml-enclave"

  observability_namespace = module.observability.namespace
  # §11.2: 2-4 GPU nodes, 8x H100 each.
  resource_quota = {
    cpu    = "192"
    memory = "3Ti"
    gpu    = "32"
  }
}

module "kafka" {
  source = "../../modules/kafka"

  broker_count  = 3 # INFRA-004
  storage_size  = "2Ti"
  storage_class = "nvme-ssd" # §11.2 storage-optimized node class
}

module "data_stores" {
  source = "../../modules/data-stores"

  minio_storage_size   = "100Ti" # §11.2 "Hot imagery: 100 TB, NVMe SSD"
  minio_storage_class  = "nvme-ssd"
  qdrant_replica_count = 3
  qdrant_storage_size  = "1Ti"
  redis_shard_count    = 6 # §11.2 "Redis cache: 512 GB, in-memory, NVMe-backed AOF"
}

module "vault" {
  source = "../../modules/vault"

  ha_replicas     = 3
  kubernetes_host = "https://kubernetes.default.svc"
}

module "gateway" {
  source = "../../modules/gateway"

  kong_replica_count = 3
}

module "istio" {
  source = "../../modules/istio"

  depends_on = [kubernetes_namespace_v1.vektor_platform, module.gateway]
}
