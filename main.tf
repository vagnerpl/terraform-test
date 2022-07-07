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

//terraform init - para iniciar o terraform na pasta
//terraform plan
//terraform apply
//terraform destroy - para apagar tudo ao terminar
