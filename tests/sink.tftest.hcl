# Test-only requirement: `mock_provider` needs Terraform >= 1.7 / OpenTofu >= 1.7.
# The module itself still supports >= 1.5 — do not bump required_version for this.
mock_provider "google" {
  # writer_identity is computed. Left to the mock provider it becomes a random
  # string, which the provider's own member validation rejects — so pin it to a
  # realistic value.
  mock_resource "google_logging_project_sink" {
    defaults = {
      writer_identity = "serviceAccount:p123-456@gcp-sa-logging.iam.gserviceaccount.com"
    }
  }
}

variables {
  project_id  = "example-project"
  name        = "example-sink"
  destination = "storage.googleapis.com/example-log-archive"
}

run "defaults_are_safe" {
  assert {
    condition     = google_logging_project_sink.this.unique_writer_identity == true
    error_message = "Sinks must default to a dedicated writer identity, not the shared project-wide one."
  }
}

# The core regression: a sink whose writer identity has no role on the
# destination applies cleanly and then exports nothing.
run "storage_destination_grants_writer_identity" {
  assert {
    condition     = length(google_storage_bucket_iam_member.writer) == 1
    error_message = "A GCS destination must get an IAM binding for the sink writer identity."
  }
  assert {
    condition     = google_storage_bucket_iam_member.writer[0].bucket == "example-log-archive"
    error_message = "The binding must target the bucket named in the destination URI."
  }
  assert {
    condition     = google_storage_bucket_iam_member.writer[0].role == "roles/storage.objectCreator"
    error_message = "GCS log sinks need roles/storage.objectCreator on the destination bucket."
  }
  assert {
    condition     = google_storage_bucket_iam_member.writer[0].member == google_logging_project_sink.this.writer_identity
    error_message = "The binding must be for this sink's own writer identity."
  }
  assert {
    condition     = output.writer_identity_permission_granted
    error_message = "writer_identity_permission_granted must report the grant that was made."
  }
}

run "bigquery_destination_grants_writer_identity" {
  variables {
    destination = "bigquery.googleapis.com/projects/other-project/datasets/log_archive"
  }

  assert {
    condition     = length(google_bigquery_dataset_iam_member.writer) == 1
    error_message = "A BigQuery destination must get an IAM binding for the sink writer identity."
  }
  assert {
    condition     = google_bigquery_dataset_iam_member.writer[0].project == "other-project"
    error_message = "The binding must target the project named in the destination URI, not var.project_id."
  }
  assert {
    condition     = google_bigquery_dataset_iam_member.writer[0].dataset_id == "log_archive"
    error_message = "The binding must target the dataset named in the destination URI."
  }
  assert {
    condition     = google_bigquery_dataset_iam_member.writer[0].role == "roles/bigquery.dataEditor"
    error_message = "BigQuery log sinks need roles/bigquery.dataEditor on the destination dataset."
  }
  assert {
    condition     = length(google_storage_bucket_iam_member.writer) == 0 && length(google_pubsub_topic_iam_member.writer) == 0
    error_message = "Only the binding matching the destination type may be created."
  }
}

run "pubsub_destination_grants_writer_identity" {
  variables {
    destination = "pubsub.googleapis.com/projects/other-project/topics/log-fanout"
  }

  assert {
    condition     = length(google_pubsub_topic_iam_member.writer) == 1
    error_message = "A Pub/Sub destination must get an IAM binding for the sink writer identity."
  }
  assert {
    condition     = google_pubsub_topic_iam_member.writer[0].topic == "log-fanout"
    error_message = "The binding must target the topic named in the destination URI."
  }
  assert {
    condition     = google_pubsub_topic_iam_member.writer[0].role == "roles/pubsub.publisher"
    error_message = "Pub/Sub log sinks need roles/pubsub.publisher on the destination topic."
  }
}

run "log_bucket_destination_grants_nothing" {
  variables {
    destination = "logging.googleapis.com/projects/example-project/locations/global/buckets/archive"
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.writer) == 0 && length(google_bigquery_dataset_iam_member.writer) == 0 && length(google_pubsub_topic_iam_member.writer) == 0
    error_message = "Log-bucket destinations need no grant, so none may be created."
  }
  assert {
    condition     = output.writer_identity_permission_granted == false
    error_message = "writer_identity_permission_granted must be false when nothing was granted."
  }
}

run "grant_can_be_opted_out" {
  variables {
    grant_writer_identity_permission = false
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.writer) == 0
    error_message = "grant_writer_identity_permission = false must suppress the binding."
  }
}

run "whitespace_only_filter_is_not_a_filter" {
  variables {
    filter = "   "
  }

  assert {
    condition     = google_logging_project_sink.this.filter == null
    error_message = "A whitespace-only filter must be sent as no filter, not as a filter matching nothing."
  }
}

run "real_filter_is_preserved" {
  variables {
    filter = "severity >= WARNING"
  }

  assert {
    condition     = google_logging_project_sink.this.filter == "severity >= WARNING"
    error_message = "A real filter must be passed through unchanged."
  }
}

run "rejects_bare_bucket_name_as_destination" {
  command = plan

  variables {
    destination = "my-log-archive"
  }

  expect_failures = [var.destination]
}

run "rejects_destination_with_wrong_service_prefix" {
  command = plan

  variables {
    destination = "gs://my-log-archive"
  }

  expect_failures = [var.destination]
}
