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
