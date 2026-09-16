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
    observability = "e2-standard-2"
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

variable "enable_loadgen" {
  description = "Create the temporary M8 cross-region load generator only for an explicitly reviewed workload run."
  type        = bool
  default     = false
}
variable "loadgen_region" {
  description = "Default region for the temporary M8 load generator per ADR-004."
  type        = string
  default     = "asia-northeast1"
}
variable "loadgen_zone" {
  description = "Zone for the temporary M8 load generator."
  type        = string
  default     = "asia-northeast1-a"
}
variable "loadgen_subnet_cidr" {
  description = "Dedicated cross-region subnet for the temporary M8 load generator."
  type        = string
  default     = "10.50.0.0/24"
}
variable "loadgen_private_ip" {
  description = "Stable private address used only while the temporary M8 load generator exists."
  type        = string
  default     = "10.50.0.10"
}
variable "loadgen_machine_type" {
  description = "Initial load-generator size; live quota/capacity is checked before M8 apply."
  type        = string
  default     = "e2-standard-2"
}

variable "enable_backup" {
  description = "Create the temporary M11 cross-region backup repository only for explicitly reviewed backup/recovery work."
  type        = bool
  default     = false
}
variable "backup_region" {
  description = "Region for temporary M11 backup/recovery infrastructure per ADR-004."
  type        = string
  default     = "asia-northeast1"
}
variable "backup_zone" {
  description = "Zone for backup-01."
  type        = string
  default     = "asia-northeast1-a"
}
variable "backup_subnet_cidr" {
  description = "Dedicated subnet for temporary M11 backup/recovery infrastructure."
  type        = string
  default     = "10.60.0.0/24"
}
variable "backup_private_ip" {
  description = "Stable private address for backup-01 while M11 backup infrastructure exists."
  type        = string
  default     = "10.60.0.10"
}
variable "backup_machine_type" {
  description = "Machine type for backup-01."
  type        = string
  default     = "e2-small"
}
variable "backup_data_disk_size_gb" {
  description = "Independent backup repository disk size for pgBackRest and Garage object copies."
  type        = number
  default     = 100
}
variable "backup_data_disk_type" {
  description = "Persistent disk type for the temporary backup repository."
  type        = string
  default     = "pd-standard"
  validation {
    condition     = contains(["pd-standard", "pd-balanced"], var.backup_data_disk_type)
    error_message = "backup_data_disk_type must be pd-standard or pd-balanced."
  }
}


variable "enable_recovery_db" {
  description = "Create the disposable M11 PostgreSQL PITR recovery VM only for an explicitly reviewed recovery experiment."
  type        = bool
  default     = false
}
variable "recovery_db_private_ip" {
  description = "Stable private address for recovery-db-01 while the PITR experiment exists."
  type        = string
  default     = "10.60.0.20"
}
variable "recovery_db_machine_type" {
  description = "Machine type for the disposable PITR recovery database VM."
  type        = string
  default     = "e2-medium"
}
variable "recovery_db_data_disk_size_gb" {
  description = "Disposable PostgreSQL recovery data disk size."
  type        = number
  default     = 30
}

variable "enable_full_dr" {
  description = "Create the temporary M11 full-DR service topology only after an explicitly reviewed recovery plan."
  type        = bool
  default     = false
}

variable "full_dr_region" {
  description = "Region for the temporary M11 full-DR service topology per ADR-004."
  type        = string
  default     = "asia-northeast1"
}

variable "full_dr_subnet_cidr" {
  description = "Dedicated subnet for the temporary M11 full-DR service topology."
  type        = string
  default     = "10.70.0.0/24"
}

variable "full_dr_private_ips" {
  description = "Stable private addresses used only while the temporary M11 full-DR topology exists."
  type        = map(string)
  default = {
    edge       = "10.70.0.10"
    app        = "10.70.0.20"
    db         = "10.70.0.30"
    storage-01 = "10.70.0.41"
    storage-02 = "10.70.0.42"
    storage-03 = "10.70.0.43"
  }
  validation {
    condition = alltrue([
      for key in ["edge", "app", "db", "storage-01", "storage-02", "storage-03"] :
      contains(keys(var.full_dr_private_ips), key)
    ])
    error_message = "full_dr_private_ips must define edge, app, db, and all three storage nodes."
  }
}

variable "full_dr_machine_types" {
  description = "Machine types for the temporary M11 full-DR service tiers."
  type        = map(string)
  default = {
    edge    = "e2-small"
    app     = "e2-medium"
    db      = "e2-medium"
    storage = "e2-small"
  }
  validation {
    condition = alltrue([
      for role in ["edge", "app", "db", "storage"] :
      contains(keys(var.full_dr_machine_types), role)
    ])
    error_message = "full_dr_machine_types must define edge, app, db, and storage."
  }
}

variable "full_dr_db_data_disk_size_gb" {
  description = "Fresh PostgreSQL data disk size for dr-db-01."
  type        = number
  default     = 30
}

variable "full_dr_storage_data_disk_size_gb" {
  description = "Fresh Garage data disk size for each full-DR storage node."
  type        = number
  default     = 30
}

variable "full_dr_data_disk_type" {
  description = "Persistent disk type for temporary full-DR data disks."
  type        = string
  default     = "pd-standard"
  validation {
    condition     = contains(["pd-standard", "pd-balanced"], var.full_dr_data_disk_type)
    error_message = "full_dr_data_disk_type must be pd-standard or pd-balanced."
  }
}
