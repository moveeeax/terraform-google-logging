locals {
  # regexall never errors on a non-match, so each of these is either an empty
  # list (destination is not of that type) or a single-element list holding the
  # captured parts of the destination URI.
  storage_match  = regexall("^storage\\.googleapis\\.com/(?P<bucket>[^/]+)$", var.destination)
  bigquery_match = regexall("^bigquery\\.googleapis\\.com/projects/(?P<project>[^/]+)/datasets/(?P<dataset>[^/]+)$", var.destination)
  pubsub_match   = regexall("^pubsub\\.googleapis\\.com/projects/(?P<project>[^/]+)/topics/(?P<topic>[^/]+)$", var.destination)

  grant_storage  = var.grant_writer_identity_permission && length(local.storage_match) > 0
  grant_bigquery = var.grant_writer_identity_permission && length(local.bigquery_match) > 0
  grant_pubsub   = var.grant_writer_identity_permission && length(local.pubsub_match) > 0
}

resource "google_logging_project_sink" "this" {
  project     = var.project_id
  name        = var.name
  destination = var.destination

  # A filter of only whitespace is not the same as no filter: it would be sent
  # to the API as a real filter. Treat it as "export everything" instead.
  filter = trimspace(var.filter) != "" ? var.filter : null

  description = var.description

  unique_writer_identity = var.unique_writer_identity
}

# A log sink is only half a working export. Cloud Logging creates the sink
# happily even when its writer identity has no permission on the destination;
# the export then fails server-side and silently drops every entry. Nothing in
# the Terraform plan or state hints at it — you find out when you go looking
# for logs that were never written. These bindings close that gap.
#
# google_*_iam_member is additive, so it does not disturb any other principal
# already bound on the destination.

resource "google_storage_bucket_iam_member" "writer" {
  count = local.grant_storage ? 1 : 0

  bucket = local.storage_match[0].bucket
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.this.writer_identity
}

resource "google_bigquery_dataset_iam_member" "writer" {
  count = local.grant_bigquery ? 1 : 0

  project    = local.bigquery_match[0].project
  dataset_id = local.bigquery_match[0].dataset
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.this.writer_identity
}

resource "google_pubsub_topic_iam_member" "writer" {
  count = local.grant_pubsub ? 1 : 0

  project = local.pubsub_match[0].project
  topic   = local.pubsub_match[0].topic
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.this.writer_identity
}
