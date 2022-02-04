variable "gcp-credentials" {
  sensitive = true
}

variable "gcp-project" {}

variable "prefix" {
  description = "Unique prefix for all created resources"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}


