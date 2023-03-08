resource "google_clouddeploy_delivery_pipeline" "gke" {
  location = "var.region"
  name     = "security-demo-pipeline"
   count       = var.use_cloud_run ? 0 : 1
  description = "Security-focused CI/CD pipeline on GCP"

  labels = {
    my_first_label = "example-label-1"

    my_second_label = "example-label-2"
  }

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

resource "google_clouddeploy_target" "test" {
  location = var.region
  name     = "test-sec"
  count       = var.use_cloud_run ? 0 : 1
  description = "test gke target"

  gke {
    cluster = "projects/${var.project_id}/locations/${var.zone}/clusters/test-sec"
  }

  
  project          = var.project_id
  require_approval = false
}

resource "google_clouddeploy_target" "prod" {
  location = var.region
  name     = "test-sec"
  count       = var.use_cloud_run ? 0 : 1
  description = "prod gke target"

  gke {
    cluster = "projects/${var.project_id}/locations/${var.zone}/clusters/prod-sec"
  }

  
  project          = var.project_id
  require_approval = true
}


