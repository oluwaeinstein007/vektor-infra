variable "namespace" {
  description = "istio-system namespace."
  type        = string
  default     = "istio-system"
}

variable "chart_version" {
  type    = string
  default = "1.24.2"
}

variable "mesh_namespaces" {
  description = "Namespaces that get the istio-injection=enabled label. SEC-001 scopes mTLS enforcement to 'all TS services' specifically — vektor-ml-enclave is deliberately excluded, since the Python enclave's isolation is enforced by NetworkPolicy (terraform/modules/vektor-ml-enclave) per §14.2, not the mesh."
  type        = list(string)
  default     = ["vektor-platform", "vektor-gateway"]
}
