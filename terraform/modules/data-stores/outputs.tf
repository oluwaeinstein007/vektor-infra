output "minio_endpoint" {
  value = "vektor-minio.${kubernetes_namespace_v1.data.metadata[0].name}.svc.cluster.local:9000"
}

output "qdrant_endpoint" {
  value = "vektor-qdrant.${kubernetes_namespace_v1.data.metadata[0].name}.svc.cluster.local:6333"
}

output "redis_endpoint" {
  value = "vektor-redis.${kubernetes_namespace_v1.data.metadata[0].name}.svc.cluster.local:6379"
}
