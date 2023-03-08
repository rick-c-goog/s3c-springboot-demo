#!/bin/bash

# bail if PROJECT_ID is not set 
export TF_VAR_project_id= 
if [[ -z "${PROJECT_ID}" ]]; then
  echo "The value of PROJECT_ID is not set. Be sure to run \"export PROJECT_ID=YOUR-PROJECT\" first"
  return
fi

# sets the current project for gcloud
gcloud config set project $PROJECT_ID
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export CLOUDBUILD_SA=$PROJECT_NUMBER@cloudbuild.gserviceaccount.com
export GITHUB_REPO_OWNER="rick-c-goog"
export REGION=us-central1

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

export DB_INSTANCE_NAME=item-db-instance
export DB_INSTANCE_PASSWORD=CHANGEME
export TESTDB_NAME=item-testdb
export TESTDB_USER=user
export TESTDB_PASSWORD=CHANGEME
export PRODDB_NAME=item-proddb
export PRODDB_USER=user
export PRODDB_PASSWORD=CHANGEME

export VPC_CONNECTOR=itemconnector
export WS_CLUSTER=my-cw-cluster