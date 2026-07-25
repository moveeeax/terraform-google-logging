variable "project_id" {
  description = "ID of the project the log sink is created in."
  type        = string
}

variable "name" {
  description = "Name of the log sink."
  type        = string
}

variable "destination" {
  description = <<-EOT
    Destination for exported logs. Must be one of:
      storage.googleapis.com/<bucket>
      bigquery.googleapis.com/projects/<project>/datasets/<dataset>
      pubsub.googleapis.com/projects/<project>/topics/<topic>
      logging.googleapis.com/projects/<project>/locations/<location>/buckets/<bucket>
  EOT
  type        = string

  validation {
    condition = anytrue([
      can(regex("^storage\\.googleapis\\.com/[^/]+$", var.destination)),
      can(regex("^bigquery\\.googleapis\\.com/projects/[^/]+/datasets/[^/]+$", var.destination)),
      can(regex("^pubsub\\.googleapis\\.com/projects/[^/]+/topics/[^/]+$", var.destination)),
      can(regex("^logging\\.googleapis\\.com/(projects|folders|organizations|billingAccounts)/[^/]+/locations/[^/]+/buckets/[^/]+$", var.destination)),
    ])
    error_message = "destination must be a full Cloud Logging sink destination URI: storage.googleapis.com/<bucket>, bigquery.googleapis.com/projects/<project>/datasets/<dataset>, pubsub.googleapis.com/projects/<project>/topics/<topic> or logging.googleapis.com/<parent>/<id>/locations/<location>/buckets/<bucket>."
  }
}

variable "filter" {
  description = "Advanced log filter selecting which entries to export. Empty (or whitespace only) exports all logs."
  type        = string
  default     = ""
}

variable "unique_writer_identity" {
  description = <<-EOT
    Whether to create a dedicated service account as the sink's writer identity.
    Keep this true. When false the sink shares the project-wide
    cloud-logs@system.gserviceaccount.com identity, so any permission granted to
    it on a destination is silently granted to every other non-unique sink in
    the project, and the grant cannot be revoked for one sink alone.
  EOT
  type        = bool
  default     = true
}

variable "grant_writer_identity_permission" {
  description = <<-EOT
    Whether to grant the sink's writer identity the minimal role it needs to
    write to the destination (storage.objectCreator, bigquery.dataEditor or
    pubsub.publisher). Without this grant Cloud Logging accepts the sink but
    every export fails server-side and no entry is ever written. Set to false
    only if the binding is managed elsewhere. No grant is created for
    logging.googleapis.com log-bucket destinations, which need none within the
    same project.
  EOT
  type        = bool
  default     = true
}

variable "description" {
  description = "Description of the log sink."
  type        = string
  default     = "Managed by Terraform"
}
