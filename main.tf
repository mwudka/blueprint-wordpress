provider "google" {
  project = var.gcp-project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "private_network" {
  name = "${var.prefix}-private-network"
}

resource "google_compute_firewall" "default" {
  name    = "${var.prefix}-web-firewall"
  network = google_compute_network.private_network.self_link

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.prefix}-private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.private_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.private_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "random_id" "sql_db_id" {
  byte_length = 8
}

resource "google_sql_database_instance" "instance" {
  name             = "${var.prefix}-${random_id.sql_db_id.hex}"
  region           = var.region
  database_version = "MYSQL_5_7"

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      private_network = google_compute_network.private_network.id
    }
  }
}

resource "random_password" "password" {
  length           = 16
  special          = false
}

resource "google_sql_user" "user" {
  name     = local.database-username
  instance = google_sql_database_instance.instance.name
  host     = local.private-ip
  password = random_password.password.result
}

data "google_compute_image" "container-optimized-os" {
  family  = "cos-stable"
  project = "cos-cloud"
}

resource "google_compute_instance" "vm_instance" {
  name         = "${var.prefix}-wordpress"
  machine_type = "e2-standard-2"

  tags = ["web"]

  allow_stopping_for_update = true

  metadata_startup_script = <<EOT
  #!/usr/bin/env bash

  echo "Creating database..."
  docker run -t --rm mysql mysql -h${local.database-host} -u${local.database-username} -p${random_password.password.result} --execute='CREATE DATABASE IF NOT EXISTS ${local.database-name}'

  echo "Starting wordpress..."

  docker run --name wordpress -p 80:80 -e WORDPRESS_DB_HOST='${local.database-host}' -e WORDPRESS_DB_USER='${local.database-username}' -e WORDPRESS_DB_PASSWORD='${random_password.password.result}' -e WORDPRESS_DB_NAME='${local.database-name}' -d wordpress
  echo "Done!"
  EOT

  boot_disk {
    initialize_params {
      image = data.google_compute_image.container-optimized-os.self_link
    }
  }

  network_interface {
    network = google_compute_network.private_network.self_link

    access_config {
    }
  }
}

locals {
  public-ip  = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
  private-ip = google_compute_instance.vm_instance.network_interface[0].network_ip
  ssh-command = "gcloud compute ssh --zone '${var.zone}' '${google_compute_instance.vm_instance.name}'  --project '${var.gcp-project}'"
  database-host = google_sql_database_instance.instance.private_ip_address
  database-name = "wordpress"
  database-username = "wordpress-user"
}
