variable "namespace" {
  description = "istio-system namespace."
  type        = string
  default     = "istio-system"
}

variable "chart_version" {
  type    = string
  default = "1.24.2"
}

variable "backend_namespace" {
  description = "SEC-001: namespace vektor-backend's services run in — every AuthorizationPolicy below targets workloads here by their Helm chart's fixed ServiceAccount-derived app.kubernetes.io/name label."
  type        = string
  default     = "vektor-backend"
}

variable "gateway_namespace" {
  description = "SEC-001: namespace Kong runs in (terraform/modules/gateway) — the source every public-facing vektor-backend service's AuthorizationPolicy allows ingress from."
  type        = string
  default     = "vektor-gateway"
}

variable "mesh_namespaces" {
  description = "Namespaces that get the istio-injection=enabled label. SEC-001 scopes mTLS enforcement to 'all TS services' specifically — vektor-ml-enclave is deliberately excluded, since the Python enclave's isolation is enforced by NetworkPolicy (terraform/modules/vektor-ml-enclave) per §14.2, not the mesh."
  type        = list(string)
  default     = ["vektor-backend", "vektor-web", "vektor-gateway"]
}
