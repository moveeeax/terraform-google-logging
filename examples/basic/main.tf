terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "logs" {
  project                     = var.project_id
  name                        = "${var.project_id}-log-archive"
  location                    = var.region
  uniform_bucket_level_access = true
}

module "logging" {
  source = "../.."

  project_id  = var.project_id
  name        = "example-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"
  filter      = "severity >= WARNING"
}

variable "project_id" {
  description = "Project ID the example log sink is created in."
  type        = string
}

variable "region" {
  description = "Region for the google provider and log bucket."
  type        = string
  default     = "us-central1"
}

output "writer_identity" {
  value = module.logging.writer_identity
}
