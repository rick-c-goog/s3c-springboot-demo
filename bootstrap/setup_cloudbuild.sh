#!/bin/bash

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export CLOUDBUILD_SA=$PROJECT_NUMBER@cloudbuild.gserviceaccount.com
REGION=us-central1
GITHUB_REPO_OWNER="VeerMuchandi"

# create build trigger connecting to the forked GitHub repo

    gcloud beta builds triggers create github \
    --name=maven-app-trigger \
    --region=$REGION \
    --repo-name="sbcrudapp" \
    --repo-owner=$GITHUB_REPO_OWNER \
    --branch-pattern="^main$" \
    --build-config="cloudbuild.yaml" \
    --substitutions _KMS_DIGEST_ALG="SHA256",_KMS_KEY_NAME=projects/$PROJECT_ID/locations/$REGION/keyRings/binauthz/cryptoKeys/vulnz-signer/cryptoKeyVersions/1,_NOTE_NAME=projects/$PROJECT_ID/notes/vulnz-note \
    --include-logs-with-status

# create a private pool
   gcloud builds worker-pools create private-pool  \
       --region=$REGION \
       --worker-disk-size=100 \
       --worker-machine-type=e2-medium

# add iam role Service Account User
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUDBUILD_SA" \
    --role="roles/iam.serviceAccountUser"

# add iam role Service Account User
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUDBUILD_SA" \
    --role="roles/clouddeploy.releaser"

# add iam role Cloud Build worker pool user
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUDBUILD_SA" \
    --role="roles/cloudbuild.workerPoolUser"

# add iam role to list notes occurences
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUDBUILD_SA" \
    --role="roles/containeranalysis.notes.occurrences.viewer"

# add iam role to attach notes
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUDBUILD_SA" \
    --role="roles/containeranalysis.notes.attacher"

# add cloud deploy runner role to the compute SA
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/cloudbuild.workerPoolUser"
