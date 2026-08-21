variable "namespace" {
  description = "Namespace for the observability stack — INFRA-009. Every other module's NetworkPolicy that allows metrics scraping references this name."
  type        = string
  default     = "vektor-observability"
}

variable "prometheus_retention" {
  type    = string
  default = "30d"
}

variable "loki_storage_size" {
  type    = string
  default = "500Gi"
}
