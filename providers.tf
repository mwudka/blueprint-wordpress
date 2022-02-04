terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }

    google = {
      source = "hashicorp/google"
      version = "4.9.0"
    }
  }
}
