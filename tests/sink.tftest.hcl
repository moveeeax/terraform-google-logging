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

# --- exclusions ---------------------------------------------------------------

run "no_exclusions_by_default" {
  assert {
    condition     = length(google_logging_project_sink.this.exclusions) == 0
    error_message = "No exclusion may be sent unless exclusions is set."
  }
}

run "exclusions_are_passed_through_with_the_key_as_name" {
  variables {
    exclusions = {
      "lb-health-checks" = {
        filter      = "resource.type = \"http_load_balancer\" AND httpRequest.requestUrl : \"/healthz\""
        description = "Load balancer health checks"
      }
      "gke-system" = {
        filter   = "resource.type = \"k8s_container\" AND resource.labels.namespace_name = \"kube-system\""
        disabled = true
      }
    }
  }

  assert {
    condition     = length(google_logging_project_sink.this.exclusions) == 2
    error_message = "Every exclusion must reach the sink."
  }

  # Map iteration is ordered by key, so gke-system comes first.
  assert {
    condition     = google_logging_project_sink.this.exclusions[0].name == "gke-system" && google_logging_project_sink.this.exclusions[0].disabled == true
    error_message = "The map key must become the exclusion name and disabled must pass through."
  }

  assert {
    condition     = google_logging_project_sink.this.exclusions[1].name == "lb-health-checks" && google_logging_project_sink.this.exclusions[1].description == "Load balancer health checks"
    error_message = "description must pass through."
  }

  assert {
    condition     = google_logging_project_sink.this.exclusions[1].disabled == false
    error_message = "disabled must default to false so a new exclusion actually excludes."
  }
}

run "rejects_exclusion_name_with_spaces" {
  command = plan

  variables {
    exclusions = { "health checks" = { filter = "httpRequest.requestUrl : \"/healthz\"" } }
  }

  expect_failures = [var.exclusions]
}

run "rejects_empty_exclusion_filter" {
  command = plan

  variables {
    exclusions = { "everything" = { filter = "  " } }
  }

  expect_failures = [var.exclusions]
}

# --- BigQuery options ---------------------------------------------------------

run "bigquery_destination_uses_partitioned_tables_by_default" {
  variables {
    destination = "bigquery.googleapis.com/projects/other-project/datasets/log_archive"
  }

  assert {
    condition     = google_logging_project_sink.this.bigquery_options[0].use_partitioned_tables == true
    error_message = "BigQuery sinks must default to partitioned tables."
  }
}

run "bigquery_partitioned_tables_can_be_turned_off" {
  variables {
    destination                     = "bigquery.googleapis.com/projects/other-project/datasets/log_archive"
    bigquery_use_partitioned_tables = false
  }

  assert {
    condition     = google_logging_project_sink.this.bigquery_options[0].use_partitioned_tables == false
    error_message = "bigquery_use_partitioned_tables = false must reach the sink."
  }
}

run "non_bigquery_destination_sends_no_bigquery_options" {
  command = plan

  assert {
    condition     = length(google_logging_project_sink.this.bigquery_options) == 0
    error_message = "bigquery_options must only be sent for BigQuery destinations."
  }
}
