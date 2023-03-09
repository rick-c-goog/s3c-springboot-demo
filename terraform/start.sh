#!/bin/bash

# bail if PROJECT_ID is not set 
export TF_VAR_project_id=rick-iac-cp
if [[ -z "${TF_VAR_project_id}" ]]; then
  echo "The value of PROJECT_ID is not set. Be sure to run \"export PROJECT_ID=YOUR-PROJECT\" first"
  return
fi

# sets the current project for gcloud
gcloud config set project $TF_VAR_project_id
export TF_VAR_project_number=$(gcloud projects describe $TF_VAR_project_id --format="value(projectNumber)")
export TF_VAR_region=us-central1
export TF_VAR_zone=us-central1-a
export TF_VAR_github_token=""
export TF_VAR_github_url="https://github.com/rick-c-goog/sbcrudapp.git"

terraform init
terraform plan
terraform apply