variable "project_id" {
  type = string
}
variable "region" {
  type    = string
  default = "asia-northeast3"
}
variable "primary_zone" {
  type    = string
  default = "asia-northeast3-a"
}
variable "subnet_cidr" {
  type    = string
  default = "10.40.0.0/24"
}
variable "enable_http" {
  type    = bool
  default = true
}
variable "boot_image" {
  type    = string
  default = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
}
variable "boot_disk_size_gb" {
  type    = number
  default = 20
}
variable "db_data_disk_size_gb" {
  type    = number
  default = 30
}
variable "garage_data_disk_size_gb" {
  type    = number
  default = 30
}
variable "observability_data_disk_size_gb" {
  type    = number
  default = 40
}
variable "machine_types" {
  type = map(string)
  default = {
    edge          = "e2-small"
    app           = "e2-medium"
    db            = "e2-medium"
    storage       = "e2-medium"
    ops           = "e2-small"
    observability = "e2-medium"
  }
  validation {
    condition     = alltrue([for role in ["edge", "app", "db", "storage", "ops", "observability"] : contains(keys(var.machine_types), role)])
    error_message = "machine_types must define edge, app, db, storage, ops, and observability."
  }
}
variable "node_machine_type_overrides" {
  description = "Optional per-node machine-type overrides for capacity recovery without resizing healthy nodes."
  type        = map(string)
  default     = {}
  validation {
    condition = alltrue([
      for name in keys(var.node_machine_type_overrides) : contains([
        "edge-01",
        "app-01",
        "db-01",
        "storage-01",
        "storage-02",
        "storage-03",
        "ops-01",
        "obs-01",
      ], name)
    ])
    error_message = "node_machine_type_overrides may contain only known runtime node names."
  }
}
variable "node_boot_disk_type_overrides" {
  description = "Optional per-node boot-disk overrides for quota recovery without changing healthy nodes."
  type        = map(string)
  default     = {}
  validation {
    condition = alltrue([
      for name, disk_type in var.node_boot_disk_type_overrides :
      contains([
        "edge-01",
        "app-01",
        "db-01",
        "storage-01",
        "storage-02",
        "storage-03",
        "ops-01",
        "obs-01",
      ], name) && contains(["pd-balanced", "pd-standard"], disk_type)
    ])
    error_message = "node_boot_disk_type_overrides may contain only known runtime nodes and pd-balanced/pd-standard values."
  }
}
