output "bootstrap_servers" {
  value = "vektor-kafka.${kubernetes_namespace_v1.streaming.metadata[0].name}.svc.cluster.local:9092"
}

output "schema_registry_url" {
  value = "http://schema-registry.${kubernetes_namespace_v1.streaming.metadata[0].name}.svc.cluster.local:8081"
}
