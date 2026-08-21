variable "namespace" {
  description = "Namespace for the Kafka cluster + Schema Registry."
  type        = string
  default     = "vektor-streaming"
}

variable "broker_count" {
  description = "INFRA-004: 3 brokers, ISR=2 per R-009 (single point of failure mitigation)."
  type        = number
  default     = 3
}

variable "storage_size" {
  description = "Per-broker PVC size."
  type        = string
  default     = "500Gi"
}

variable "storage_class" {
  description = "StorageClass backing broker PVCs — should map to NVMe-backed storage per §11.2."
  type        = string
  default     = "nvme-ssd"
}

variable "chart_version" {
  description = "Bitnami kafka chart version, pinned deliberately (R-006 mitigation: no unreviewed drift)."
  type        = string
  default     = "31.5.0"
}

variable "schema_registry_image" {
  type    = string
  default = "confluentinc/cp-schema-registry:7.7.1"
}
