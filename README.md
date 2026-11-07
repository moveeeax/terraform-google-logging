# terraform-google-logging

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
project log sink (`google_logging_project_sink`). It exports log entries that
match a filter to a Cloud Storage bucket, BigQuery dataset or Pub/Sub topic.

The module also grants the sink's writer identity the minimal role it needs on
that destination, because a sink without such a grant is the classic silent
failure of Cloud Logging exports: Terraform applies cleanly, the sink shows up
in the console, and not a single entry is ever written. See
[Writer identity](#writer-identity).

## Usage

```hcl
module "logging" {
  source = "github.com/moveeeax/terraform-google-logging?ref=v1.0.0"

  project_id  = var.project_id
  name        = "warnings-to-gcs"
  destination = "storage.googleapis.com/my-log-archive"
  filter      = "severity >= WARNING"
}
```

### Exclusions and BigQuery

```hcl
module "logging_bq" {
  source = "github.com/moveeeax/terraform-google-logging?ref=v1.0.0"

  project_id  = var.project_id
  name        = "all-to-bigquery"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/log_archive"

  exclusions = {
    "lb-health-checks" = {
      filter      = "resource.type = \"http_load_balancer\" AND httpRequest.requestUrl : \"/healthz\""
      description = "Load balancer health checks"
    }
    "gke-system-sample" = {
      # sample() drops 90% of the matching entries and keeps the rest.
      filter = "resource.type = \"k8s_container\" AND resource.labels.namespace_name = \"kube-system\" AND sample(insertId, 0.9)"
    }
  }
}
```

The `exclusions` map key becomes the exclusion name. The exclusions belong to
this sink and only filter what it exports.
`disabled = true` keeps an exclusion in place without excluding anything.

For BigQuery destinations, `bigquery_use_partitioned_tables = true` makes the
sink write to partitioned tables. The default is `false`, which keeps the API's
behaviour of one dated table per day (`syslog_20170523`), so existing sinks
plan no change. With partitioned tables the date suffix is gone and queries
need partition syntax instead; new sinks usually want `true`.
The setting is ignored for other destinations.

A runnable example lives in [`examples/basic`](examples/basic).

## Writer identity

Cloud Logging writes exported entries as a service account — the sink's *writer
identity*. Creating the sink does not give that account any access to the
destination, and the export failure that follows is invisible from Terraform:
the plan is empty, the state is healthy, the logs simply never arrive.

With `grant_writer_identity_permission = true` (the default) this module creates
the matching binding for you:

| Destination                   | Role granted                | Resource                             |
|-------------------------------|-----------------------------|--------------------------------------|
| `storage.googleapis.com/...`  | `roles/storage.objectCreator` | `google_storage_bucket_iam_member`   |
| `bigquery.googleapis.com/...` | `roles/bigquery.dataEditor` | `google_bigquery_dataset_iam_member` |
| `pubsub.googleapis.com/...`   | `roles/pubsub.publisher`    | `google_pubsub_topic_iam_member`     |
| `logging.googleapis.com/...`  | none — a log bucket in the same project needs no grant | — |

The bindings are `_iam_member` (additive), so they never overwrite other
principals on the destination. The credentials running Terraform need permission
to set IAM on the destination; if that binding is managed elsewhere, set
`grant_writer_identity_permission = false` and check the
`writer_identity_permission_granted` output to be sure you meant it.

Keep `unique_writer_identity = true`. When it is false every non-unique sink in
the project shares one identity, so a grant made for this sink silently applies
to all of them and cannot be revoked for one sink alone.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name                     | Description                                              | Type     | Default                  | Required |
|--------------------------|----------------------------------------------------------|----------|--------------------------|:--------:|
| `project_id`                       | ID of the project the sink is created in.                                  | `string` | n/a                      |   yes    |
| `name`                             | Name of the log sink.                                                      | `string` | n/a                      |   yes    |
| `destination`                      | Destination URI for exported logs. Validated against the four known forms. | `string` | n/a                      |   yes    |
| `filter`                           | Advanced log filter selecting entries. Empty exports all logs.             | `string` | `""`                     |    no    |
| `unique_writer_identity`           | Whether to create a dedicated writer identity.                             | `bool`   | `false`                  |    no    |
| `grant_writer_identity_permission` | Whether to grant the writer identity its role on the destination.          | `bool`   | `true`                   |    no    |
| `description`                      | Description of the log sink.                                               | `string` | `"Managed by Terraform"` |    no    |
| `exclusions`                       | Entries to drop before export, keyed by exclusion name.                    | `map`    | `{}`                     |    no    |
| `bigquery_use_partitioned_tables`  | BigQuery destinations only: write to partitioned tables.                   | `bool`   | `true`                   |    no    |

## Outputs

| Name                                 | Description                                                          |
|--------------------------------------|----------------------------------------------------------------------|
| `id`                                 | Identifier of the log sink.                                          |
| `name`                               | Name of the log sink.                                                |
| `writer_identity`                    | Service account that writes exported logs.                           |
| `writer_identity_permission_granted` | Whether this module granted that identity a role on the destination. |

## Tests

```
terraform test
```

The suite in [`tests/`](tests) runs against a mocked provider — no credentials,
no network, no cloud resources — and is wired into CI. It requires Terraform or
OpenTofu >= 1.7 for `mock_provider`; the module itself still supports >= 1.5.

## License

[MIT](LICENSE)
