#!/bin/bash

source env.sh

#create a key ring
gcloud kms keyrings create "binauthz" \
  --project "${PROJECT_ID}" \
  --location "${REGION}"

# create signing keys
gcloud kms keys create "vulnz-signer" \
  --project "${PROJECT_ID}" \
  --location "${REGION}" \
  --keyring "binauthz" \
  --purpose "asymmetric-signing" \
  --default-algorithm "rsa-sign-pkcs1-2048-sha256"

# Create a container analysis note with name vulnz-note
curl "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=vulnz-note" \
  --request "POST" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "X-Goog-User-Project: ${PROJECT_ID}" \
  --data-binary @- <<EOF
    {
      "name": "projects/${PROJECT_ID}/notes/vulnz-note",
      "attestation": {
        "hint": {
          "human_readable_name": "Vulnerability scan note"
        }
      }
    }
EOF

# Grant the Cloud Build service account permission to view and attach the vulnz-note note to container images

curl "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/vulnz-note:setIamPolicy" \
  --request POST \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "X-Goog-User-Project: ${PROJECT_ID}" \
  --data-binary @- <<EOF
    {
      "resource": "projects/${PROJECT_ID}/notes/vulnz-note",
      "policy": {
        "bindings": [
          {
            "role": "roles/containeranalysis.notes.occurrences.viewer",
            "members": [
              "serviceAccount:${CLOUDBUILD_SA_}"
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

gcloud container binauthz attestors create "vulnz-attestor" \
  --project "${PROJECT_ID}" \
  --attestation-authority-note-project "${PROJECT_ID}" \
  --attestation-authority-note "vulnz-note" \
  --description "Vulnerability scan attestor"

# Add the public key for attestors signing key

gcloud beta container binauthz attestors public-keys add \
  --project "${PROJECT_ID}" \
  --attestor "vulnz-attestor" \
  --keyversion "1" \
  --keyversion-key "vulnz-signer" \
  --keyversion-keyring "binauthz" \
  --keyversion-location "${REGION}" \
  --keyversion-project "${PROJECT_ID}"

# Grant the Cloud Build service account permission to view attestations made by vulnz-attestor
gcloud container binauthz attestors add-iam-policy-binding "vulnz-attestor" \
  --project "${PROJECT_ID}" \
  --member "serviceAccount:${CLOUDBUILD_SA}" \
  --role "roles/binaryauthorization.attestorsViewer"

# Grant the Cloud Build service account permission to sign objects using the vulnz-signer key
gcloud kms keys add-iam-policy-binding "vulnz-signer" \
  --project "${PROJECT_ID}" \
  --location "${REGION}" \
  --keyring "binauthz" \
  --member "serviceAccount:${CLOUDBUILD_SA}" \
  --role 'roles/cloudkms.signerVerifier'

