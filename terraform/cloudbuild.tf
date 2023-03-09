

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
    members = ["serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"]
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
    app_installation_id = 300
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

resource "google_cloudbuild_trigger" "repo-trigger" {
  provider = google-beta
  location = "us-central1"

  repository_event_config {
    repository = google_cloudbuildv2_repository.git-repository.id
    push {
      branch = "main"
    }
  }

  filename = "cloudbuild.yaml"
}