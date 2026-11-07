# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2026-11-07

### Added

- `exclusions` input, a map keyed by exclusion name of
  `{ filter, description, disabled = false }`, rendered as the sink's
  `exclusions` blocks.
- `bigquery_use_partitioned_tables` input, rendered as
  `bigquery_options.use_partitioned_tables` for BigQuery destinations only.
  It defaults to `false`, the API's own default, so existing sinks keep
  writing dated tables.

### Changed

- CI: bump actions to their current majors, pin tool versions, and restrict the
  workflow token to `contents: read`.
- CI: add Dependabot for GitHub Actions and the Terraform provider.
- Docs: pin the README usage `source` to a release tag; fix the LICENSE year.

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-google-logging/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/moveeeax/terraform-google-logging/compare/v1.1.0...v1.2.0
[1.0.0]: https://github.com/moveeeax/terraform-google-logging/releases/tag/v1.0.0
