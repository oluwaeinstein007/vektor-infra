variable "namespace" {
  description = "Namespace the Python enclave runs in. VEKTOR-PRD.md §14.2 names it vektor-ml-enclave explicitly."
  type        = string
  default     = "vektor-ml-enclave"
}

variable "platform_namespace" {
  description = "Namespace coa-svc (the only permitted gRPC caller) runs in."
  type        = string
  default     = "vektor-backend"
}

variable "observability_namespace" {
  description = "Namespace Prometheus runs in — needs ingress to scrape enclave pod metrics."
  type        = string
  default     = "vektor-observability"
}

variable "grpc_port" {
  description = "llm-cloud-svc gRPC port (vektor-proto/proto/llm.proto LLMService)."
  type        = number
  default     = 50051
}

variable "metrics_port" {
  description = "Prometheus scrape port exposed by both vektor-ml services."
  type        = number
  default     = 9090
}

variable "dns_namespace" {
  description = "SEC-002: namespace CoreDNS (or equivalent) runs in — the enclave's DNS-egress hole is scoped to only this namespace, not the whole cluster. Defaults to kube-system (k3s and most standard clusters); override for a cluster with DNS elsewhere."
  type        = string
  default     = "kube-system"
}

variable "resource_quota" {
  description = "Hard resource ceiling for the whole enclave namespace — §14.2 'resource quotas enforced (CPU, memory, GPU) to prevent runaway processes'."
  type = object({
    cpu    = string
    memory = string
    gpu    = string
  })
  default = {
    cpu    = "64"
    memory = "512Gi"
    gpu    = "8"
  }
}
