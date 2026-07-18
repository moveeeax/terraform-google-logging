# terraform-google-logging

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
project log sink (`google_logging_project_sink`). It exports log entries that
match a filter to a Cloud Storage bucket, BigQuery dataset or Pub/Sub topic.

## Usage

```hcl
module "logging" {
  source = "github.com/cybercapybara/terraform-google-logging"

  project_id  = var.project_id
  name        = "warnings-to-gcs"
  destination = "storage.googleapis.com/my-log-archive"
  filter      = "severity >= WARNING"
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name                     | Description                                              | Type     | Default                  | Required |
|--------------------------|----------------------------------------------------------|----------|--------------------------|:--------:|
| `project_id`             | ID of the project the sink is created in.                | `string` | n/a                      |   yes    |
| `name`                   | Name of the log sink.                                    | `string` | n/a                      |   yes    |
| `destination`            | Destination for exported logs.                           | `string` | n/a                      |   yes    |
| `filter`                 | Advanced log filter selecting entries.                   | `string` | `""`                     |    no    |
| `unique_writer_identity` | Whether to create a dedicated writer identity.           | `bool`   | `true`                   |    no    |
| `description`            | Description of the log sink.                             | `string` | `"Managed by Terraform"` |    no    |

## Outputs

| Name              | Description                                       |
|-------------------|---------------------------------------------------|
| `id`              | Identifier of the log sink.                      |
| `name`            | Name of the log sink.                            |
| `writer_identity` | Service account that writes exported logs.       |

## License

[MIT](LICENSE)
