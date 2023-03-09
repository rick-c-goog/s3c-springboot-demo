

resource "google_secret_manager_secret" "github-token-secret" {
  provider = google-beta
  secret_id = "github-token-secret"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "github-token-secret-version" {
  provider = google-beta
  secret = google_secret_manager_secret.github-token-secret.id
  secret_data = var.github_token
}

data "google_iam_policy" "p4sa-secretAccessor" {
  provider = google-beta
  binding {
    role = "roles/secretmanager.secretAccessor"
    // Here, 123456789 is the Google Cloud project number for my-project-name.
    members = ["serviceAccount:service-${var.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
  }
}

resource "google_secret_manager_secret_iam_policy" "policy" {
  provider = google-beta
  secret_id = google_secret_manager_secret.github-token-secret.secret_id
  policy_data = data.google_iam_policy.p4sa-secretAccessor.policy_data
}

resource "google_cloudbuildv2_connection" "gh-connection" {
  provider = google-beta
  location = var.region
  name = "springboot-github-connection"

  github_config {
    app_installation_id = 33819418
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github-token-secret-version.id
    }
  }
}


resource "google_cloudbuildv2_repository" "gh-repository" {
  provider = google-beta
  name = "my-repo"
  parent_connection = google_cloudbuildv2_connection.gh-connection.id
  remote_uri = var.github_url
}

resource "google_cloudbuild_trigger" "build-trigger" {
  provider = google-beta
  location = var.region
  name="maven-app-trigger"
  repository_event_config {
    repository = google_cloudbuildv2_repository.gh-repository.id
    push {
      branch = "main"
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _KMS_DIGEST_ALG = "SHA256"
    _KMS_KEY_NAME = "projects/${var.project_id}/locations/${var.region}/keyRings/binauthz/cryptoKeys/vulnz-signer/cryptoKeyVersions/1"
    _NOTE_NAME= "projects/${var.project_id}/notes/vulnz-note"
  }

}


resource "google_cloudbuild_trigger" "qa-trigger" {
  provider = google-beta
  location = var.region
  name="automated-qa"
  
  source_to_build {
    uri       = var.github_url
    ref       = "refs/heads/main"
    repo_type = "GITHUB"
  }
  approval_config {
     approval_required = true 
  }

  filename = "cloudbuild.yaml"
  substitutions = {
    _KMS_DIGEST_ALG = "SHA256"
    _KMS_KEY_NAME = "projects/${var.project_id}/locations/${var.region}/keyRings/binauthz/cryptoKeys/qa-signer/cryptoKeyVersions/1"
    _NOTE_NAME= "projects/${var.project_id}/notes/qa-note"
  }

}


resource "google_cloudbuild_worker_pool" "pool" {
  name = "my-pool"
  location = var.region
  worker_config {
    disk_size_gb = 100
    machine_type = "e2-standard-4"
    no_external_ip = false
  }
  network_config {
    peered_network = "default"
    peered_network_ip_range = "/29"
  }
  depends_on = [google_service_networking_connection.worker_pool_conn]
}

module "project-iam-bindings" {
  source   = "terraform-google-modules/iam/google//modules/projects_iam"
  projects = [var.project_id]
  mode     = "additive"
  bindings = {
    "roles/iam.serviceAccountUser" = [
      "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
    ]
    "roles/clouddeploy.releaser" = [
      "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
      
    ]
     "roles/cloudbuild.workerPoolUser" = [
      "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
    ]
    "roles/clouddeploy.releaser" = [
      "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
      
    ]
     "roles/cloudbuild.workerPoolUser" = [
      "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com",
    ]
  }
}