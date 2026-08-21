output "namespace" {
  description = "For other modules' NetworkPolicies to allow scrape/export traffic from."
  value       = kubernetes_namespace_v1.observability.metadata[0].name
}
