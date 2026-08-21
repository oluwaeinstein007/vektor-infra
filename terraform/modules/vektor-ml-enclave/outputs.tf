output "namespace" {
  description = "Name of the created enclave namespace, for wiring into other modules (e.g. gateway routing)."
  value       = kubernetes_namespace_v1.vektor_ml_enclave.metadata[0].name
}
