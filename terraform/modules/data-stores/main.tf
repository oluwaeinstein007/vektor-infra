# INFRA-006 — Deploy MinIO + Qdrant + Redis Cluster.
# See §10.4 (Data Storage) for what each backs: MinIO is imagery/video/model
# weights/reports; Qdrant is the RAG vector store (doctrine + entity
# similarity, ML-008/ML-009); Redis is hot entity cache + alert pub/sub +
# BullMQ backend.

resource "kubernetes_namespace_v1" "data" {
  metadata {
    name = var.namespace
    labels = {
      "vektor.io/tier" = "data"
    }
  }
}

resource "helm_release" "minio" {
  name       = "vektor-minio"
  namespace  = kubernetes_namespace_v1.data.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "minio"
  version    = "14.8.6"

  set {
    name  = "mode"
    value = "distributed"
  }
  set {
    name  = "statefulset.replicaCount"
    value = "4"
  }
  set {
    name  = "persistence.size"
    value = var.minio_storage_size
  }
  set {
    name  = "persistence.storageClass"
    value = var.minio_storage_class
  }
  # Buckets referenced by §12.4's retention policy — created at install time
  # so vektor-platform's storage-svc code never has to special-case "does
  # this bucket exist yet".
  set {
    name  = "provisioning.enabled"
    value = "true"
  }
  set {
    name  = "provisioning.buckets[0].name"
    value = "vektor-imagery"
  }
  set {
    name  = "provisioning.buckets[1].name"
    value = "vektor-fmv-clips"
  }
  set {
    name  = "provisioning.buckets[2].name"
    value = "vektor-model-weights"
  }
  set {
    name  = "provisioning.buckets[3].name"
    value = "vektor-reports"
  }
}

resource "helm_release" "qdrant" {
  name       = "vektor-qdrant"
  namespace  = kubernetes_namespace_v1.data.metadata[0].name
  repository = "https://qdrant.github.io/qdrant-helm"
  chart      = "qdrant"
  version    = "1.13.0"

  set {
    name  = "replicaCount"
    value = var.qdrant_replica_count
  }
  set {
    name  = "persistence.size"
    value = var.qdrant_storage_size
  }
}

resource "helm_release" "redis_cluster" {
  name       = "vektor-redis"
  namespace  = kubernetes_namespace_v1.data.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "redis-cluster"
  version    = "11.4.7"

  set {
    name  = "cluster.nodes"
    value = var.redis_shard_count * (var.redis_replicas_per_shard + 1)
  }
  set {
    name  = "cluster.replicas"
    value = var.redis_replicas_per_shard
  }
  set {
    name  = "persistence.enabled"
    value = "true"
  }
}
