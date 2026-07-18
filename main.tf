resource "google_logging_project_sink" "this" {
  project     = var.project_id
  name        = var.name
  destination = var.destination
  filter      = var.filter != "" ? var.filter : null
  description = var.description

  unique_writer_identity = var.unique_writer_identity
}
