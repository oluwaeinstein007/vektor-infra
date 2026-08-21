output "kong_proxy_service" {
  value = "vektor-kong-kong-proxy.${kubernetes_namespace_v1.gateway.metadata[0].name}.svc.cluster.local"
}

output "keycloak_url" {
  value = "http://vektor-keycloak.${kubernetes_namespace_v1.gateway.metadata[0].name}.svc.cluster.local"
}
