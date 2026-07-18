variable "project_id" {
  description = "ID of the project the log sink is created in."
  type        = string
}

variable "name" {
  description = "Name of the log sink."
  type        = string
}

variable "destination" {
  description = "Destination for exported logs, e.g. storage.googleapis.com/<bucket> or bigquery.googleapis.com/projects/<p>/datasets/<d>."
  type        = string
}

variable "filter" {
  description = "Advanced log filter selecting which entries to export. Empty exports all logs."
  type        = string
  default     = ""
}

variable "unique_writer_identity" {
  description = "Whether to create a dedicated service account as the sink's writer identity."
  type        = bool
  default     = true
}

variable "description" {
  description = "Description of the log sink."
  type        = string
  default     = "Managed by Terraform"
}
