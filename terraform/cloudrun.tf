

resource "google_cloud_run_service" "test-service" {
  name     = "test-sec"
  location = var.region
  count    = var.use_cloud_run ? 1 : 0
  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "1"
      }
    }
  }

  autogenerate_revision_name = true

}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "test_noauth_policy" {
  count    = var.use_cloud_run ? 1 : 0
  location = google_cloud_run_service.test_service.location
  service  = google_cloud_run_service.test_service.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_cloud_run_service" "prod-service" {
  name     = "prod-sec"
  location = var.region
  count    = var.use_cloud_run ? 1 : 0
  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "3"
      }
    }
  }

  autogenerate_revision_name = true

  
}

resource "google_cloud_run_service_iam_policy" "prod_noauth_policy" {
  count    = var.use_cloud_run ? 1 : 0
  location = google_cloud_run_service.prod_service.location
  service  = google_cloud_run_service.prod_service.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
