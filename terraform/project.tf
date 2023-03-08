
/******************************************
1. Project Services Configuration
 *****************************************/
module "activate_service_apis" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  project_id                  = var.project_id
  enable_apis                 = true

  activate_apis = [
    "container.googleapis.com", "cloudbuild.googleapis.com","artifactregistry.googleapis.com", "containerregistry.googleapis.com", "clouddeploy.googleapis.com",
    "cloudresourcemanager.googleapis.com", "binaryauthorization.googleapis.com","cloudkms.googleapis.com",
    "run.googleapis.com", "workstations.googleapis.com", "containersecurity.googleapis.com","containerscanning.googleapis.com",
    "cloudresourcemanager.googleapis.com","servicenetworking.googleapis.com","sqladmin.googleapis.com"
  ]

  disable_services_on_destroy = false
  
}

/******************************************
2.  SA IAM policy bindings
 *****************************************/

data "google_compute_default_service_account" "default" {
  project = var.project_id
}
resource "google_project_iam_binding" "set_jobrunner_binding" {
  project = var.project_id
  
   members  =  ["serviceAccount:${data.google_compute_default_service_account.default.email}"]
   role    = "roles/clouddeploy.jobRunner"
}
resource "google_project_iam_binding" "developer" {
  project = var.project_id
  
   members  =  ["serviceAccount:${data.google_compute_default_service_account.default.email}"]
   role    = "roles/container.developer"
}

resource "google_project_iam_binding" "serviceaccount" {
  project = var.project_id
  
   members  =  ["serviceAccount:${data.google_compute_default_service_account.default.email}"]
   role    = "roles/iam.serviceAccountUser"
}



/******************************************
3.  Create Artifact Registry Repo
 *****************************************/
resource "google_artifact_registry_repository" "my-repo" {
  location      = "us-central1"
  repository_id = "maven-demo-app"
  description   = "maven demo app"
  format        = "DOCKER"
}

/******************************************
3.  Create Artifact Registry Repo
 *****************************************/
resource "null_resource" "update_templates" {
  provisioner "local-exec" {
    command = <<-EOT
    gcloud auth configure-docker us-central1-docker.pkg.dev
    sed -e "s/project-id-here/${var.project_id}/" templates/template.clouddeploy.yaml > clouddeploy.yaml
    sed -e "s/project-id-here/${var.project_id}/" templates/template.allowlist-policy.yaml > policy/binauthz/allowlist-policy.yaml
    sed -e "s/project-id-here/${var.project_id}/" templates/template.attestor-policy.yaml > policy/binauthz/attestor-policy.yaml
  EOT
  }
}