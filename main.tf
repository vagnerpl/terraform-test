//Create environment variable pointing to the file where the credentials are stored
//export GOOGLE_APPLICATION_CREDENTIALS={{path}}

provider "google" {
    region = "us-central1"
}

resource "google_pubsub_topic" "gross-data-loaded" {
  name = "gross-data-loaded-topic"
  message_retention_duration = "86600s"
}

resource "google_storage_bucket" "gross-data" {
  name          = "gross-data"
  location      = "US"

  uniform_bucket_level_access = true

  storage_class = "STANDARD"

  lifecycle_rule {
    condition {
      age = "60"
      matches_storage_class = "STANDARD"
    }
    action {
      type = "SetStorageClass"
      storage_class = "NEARLINE"
    }    
  }
  lifecycle_rule {
    condition {
      age = "365"
      matches_storage_class = "NEARLINE"
    }
    action {
      type = "SetStorageClass"
      storage_class = "ARCHIVE"
    }    
  }
}

resource "google_storage_notification" "gross-notification" {
  bucket         = google_storage_bucket.gross-data.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.gross-data-loaded.id
  event_types    = ["OBJECT_FINALIZE"]
  depends_on = [google_pubsub_topic_iam_binding.binding]
}

data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = google_pubsub_topic.gross-data-loaded.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_compute_network" "vpc-network" {
  name                    = "vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "us-central1-subnet" {
  name          = "us-central1-subnet"
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.vpc-network.id
}

resource "google_sql_database_instance" "pnl-data" {
  name             = "pnl-data"
  database_version = "MYSQL_5_7"
  region           = "us-central1"

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc-network.id
    }
  }
}

resource "google_sql_database" "database" {
  name     = "pnl-db"
  instance = google_sql_database_instance.pnl-data.name
}

/*resource "google_compute_instance" "primeiravm" {
  name         = "primeiravm"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.self_link

    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = "echo hi > /test.txt"
}*/

//terraform init - para iniciar o terraform na pasta
//terraform plan
//terraform apply
//terraform destroy - para apagar tudo ao terminar
