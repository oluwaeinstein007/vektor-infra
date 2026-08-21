output "vault_addr" {
  value = "http://vektor-vault.${kubernetes_namespace_v1.vault.metadata[0].name}.svc.cluster.local:8200"
}
