variable "project_id" {
  type = string
}

variable "admin_oslogin_members" {
  description = "Owner-controlled user:/group: principals that may use IAP + OS Admin Login and perform the initial runtime apply."
  type        = set(string)
  default     = []
}
