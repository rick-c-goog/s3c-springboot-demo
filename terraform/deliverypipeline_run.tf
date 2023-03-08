resource "google_clouddeploy_delivery_pipeline" "run" {
  location = "var.region"
  name     = "security-demo-pipeline"
  count       = var.use_cloud_run ? 1 : 0
  description = "Security-focused CI/CD pipeline on GCP"

  project = var.project_id

  serial_pipeline {
    stages {
      profiles  = ["test"]
      target_id = "test-sec"
    }

    stages {
      profiles  = ["prod"]
      target_id = "prod-sec"
    }
  }
}

resource "google_clouddeploy_target" "run-test" {
  location = var.region
  name     = "test-sec"
  count       = var.use_cloud_run ? 1 : 0
  description = "test cloud run target"

  run {
    location = "projects/${var.project_id}}/locations/${var.region}"
  }
  provider = google-beta
  
  project          = var.project_id
  require_approval = false
}

resource "google_clouddeploy_target" "run-prod" {
  location = var.region
  name     = "prod-sec"
  count       = var.use_cloud_run ? 1 : 0
  description = "prod cloud run target"

  run {
    location = "projects/${var.project_id}}/locations/${var.region}"
  }
  provider = google-beta
  
  project          = var.project_id
  require_approval = true
}


