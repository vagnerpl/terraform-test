//Create environment variable pointing to the file where the credentials are stored
//export GOOGLE_APPLICATION_CREDENTIALS={{path}}

provider "google" {
    region = "us-central1"
}

#VPC Resources
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

#PubSub topic to notify Cloud Run about new files in Cloud Storage
resource "google_pubsub_topic" "gross-data-loaded" {
  name = "gross-data-loaded-topic"
  message_retention_duration = "86600s"
}

#Bucket to receive Gross Data files
resource "google_storage_bucket" "gross-data" {
  name          = "gross-data"
  location      = "US"

  uniform_bucket_level_access = true

  storage_class = "STANDARD"

  lifecycle_rule {
    condition {
      age = "60"
      matches_storage_class = ["STANDARD"]
    }
    action {
      type = "SetStorageClass"
      storage_class = "NEARLINE"
    }    
  }
  lifecycle_rule {
    condition {
      age = "365"
      matches_storage_class = ["NEARLINE"]
    }
    action {
      type = "SetStorageClass"
      storage_class = "ARCHIVE"
    }    
  }
}

#Bucket notification to be sent when new files are uploaded
resource "google_storage_notification" "gross-notification" {
  bucket         = google_storage_bucket.gross-data.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.gross-data-loaded.id
  event_types    = ["OBJECT_FINALIZE"]
  depends_on = [google_pubsub_topic_iam_binding.binding]
}

#Pub/Sub IAM entries
data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = google_pubsub_topic.gross-data-loaded.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

#Database Resources
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
  charset = "utf8"
  collation = "utf8_general_ci"
}

resource "google_sql_user" "users" {
  name = "root"
  instance = google_sql_database_instance.pnl-data.name
  password = "mypassw0rd"
}

#GKE cluster to run the main application
resource "google_container_cluster" "gke_cluster" {
  name     = "gke-cluster"
  location = "us-central1"
  
  initial_node_count       = 1
  remove_default_node_pool = true  

  network    = google_compute_network.vpc-network.name
  subnetwork = google_compute_subnetwork.us-central1-subnet.name
}

resource "google_container_node_pool" "nodes_pool" {
  name       = "nodes-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.gke_cluster.name
  node_count = 2

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = "dev"
    }

    machine_type = "g1-small"
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
