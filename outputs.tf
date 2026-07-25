output "id" {
  description = "Identifier of the log sink."
  value       = google_logging_project_sink.this.id
}

output "name" {
  description = "Name of the log sink."
  value       = google_logging_project_sink.this.name
}

output "writer_identity" {
  description = "Service account identity that writes exported logs to the destination."
  value       = google_logging_project_sink.this.writer_identity
}

output "writer_identity_permission_granted" {
  description = "Whether this module granted the writer identity a role on the destination. False means the destination needs no grant (log bucket) or the grant is managed elsewhere; in the latter case an ungranted sink exports nothing."
  value       = local.grant_storage || local.grant_bigquery || local.grant_pubsub
}
