#!/bin/bash

source bootstrap/env.sh

#create a key ring
#gcloud kms keyrings create "binauthz" \
#  --project "${PROJECT_ID}" \
#  --location "${REGION}"

# create signing keys
gcloud beta builds triggers create github \
    --name=automated-qa \  
    --region=$REGION \
    --repo-name="sbcrudapp" \
    --repo-owner=$GITHUB_REPO_OWNE \
    --branch-pattern="^main$" \
    --require-approval \
    --build-config="cloudbuild-automated-qa.yaml" \
    --substitutions _KMS_DIGEST_ALG="SHA256",_KMS_KEY_NAME=projects/$PROJECT_ID/locations/$REGION/keyRings/binauthz/cryptoKeys/qa-signer/cryptoKeyVersions/1,_NOTE_NAME=projects/$PROJECT_ID/notes/qa-note \                                               
    --include-logs-with-status

gcloud kms keys create "qa-signer" \
  --project "${PROJECT_ID}" \
  --location "${REGION}" \
  --keyring "binauthz" \
  --purpose "asymmetric-signing" \
  --default-algorithm "rsa-sign-pkcs1-2048-sha256"

# Create a container analysis note with name vulnz-note
curl "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=qa-note" \
  --request "POST" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "X-Goog-User-Project: ${PROJECT_ID}" \
  --data-binary @- <<EOF
    {
      "name": "projects/${PROJECT_ID}/notes/qa-note",
      "attestation": {
        "hint": {
          "human_readable_name": "QA test note"
        }
      }
    }
EOF

# Grant the Cloud Build service account permission to view and attach the vulnz-note note to container images

curl "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/qa-note:setIamPolicy" \
  --request POST \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "X-Goog-User-Project: ${PROJECT_ID}" \
  --data-binary @- <<EOF
    {
      "resource": "projects/${PROJECT_ID}/notes/qa-note",
      "policy": {
        "bindings": [
          {
            "role": "roles/containeranalysis.notes.occurrences.viewer",
            "members": [
              "serviceAccount:${CLOUDBUILD_SA}"
            ]
          },
          {
            "role": "roles/containeranalysis.notes.attacher",
            "members": [
              "serviceAccount:${CLOUDBUILD_SA}"
            ]
          }
        ]
      }
    }
EOF

# Create vulnerability scan attestor

gcloud container binauthz attestors create "qa-attestor" \
  --project "${PROJECT_ID}" \
  --attestation-authority-note-project "${PROJECT_ID}" \
  --attestation-authority-note "qa-note" \
  --description "QA test attestor"

# Add the public key for attestors signing key

gcloud beta container binauthz attestors public-keys add \
  --project "${PROJECT_ID}" \
  --attestor "qa-attestor" \
  --keyversion "1" \
  --keyversion-key "qa-signer" \
  --keyversion-keyring "binauthz" \
  --keyversion-location "${REGION}" \
  --keyversion-project "${PROJECT_ID}"

# Grant the Cloud Build service account permission to view attestations made by vulnz-attestor
gcloud container binauthz attestors add-iam-policy-binding "qa-attestor" \
  --project "${PROJECT_ID}" \
  --member "serviceAccount:${CLOUDBUILD_SA}" \
  --role "roles/binaryauthorization.attestorsViewer"

# Grant the Cloud Build service account permission to sign objects using the vulnz-signer key
gcloud kms keys add-iam-policy-binding "qa-signer" \
  --project "${PROJECT_ID}" \
  --location "${REGION}" \
  --keyring "binauthz" \
  --member "serviceAccount:${CLOUDBUILD_SA}" \
  --role 'roles/cloudkms.signerVerifier'