#!/bin/bash
source bootstrap/env.sh


gcloud services enable \
  cloudresourcemanager.googleapis.com \
  servicenetworking.googleapis.com \
  sqladmin.googleapis.com 

# Test cluster
echo "creating test-sec..."

gcloud beta container --project "${PROJECT_ID}" clusters create "test-sec" \
--zone "us-central1-a" --no-enable-basic-auth  \
--release-channel "rapid" --machine-type "g1-small" --image-type "COS_CONTAINERD" \
--disk-type "pd-standard" --disk-size "30" --metadata disable-legacy-endpoints=true \
--scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
--max-pods-per-node "110" --num-nodes "1" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM \
--enable-ip-alias --network "projects/${PROJECT_ID}/global/networks/default" \
--subnetwork "projects/${PROJECT_ID}/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility \
--default-max-pods-per-node "110" --no-enable-master-authorized-networks \
--enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 \
--enable-shielded-nodes --node-locations "us-central1-a" --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
--workload-pool=$PROJECT_ID.svc.id.goog \
 --async

# Prod cluster
echo "creating prod-sec..."
gcloud beta container --project "$PROJECT_ID" clusters create "prod-sec" \
--zone "us-central1-a" --no-enable-basic-auth  \
--release-channel "rapid" --machine-type "g1-small" --image-type "COS_CONTAINERD" \
--disk-type "pd-standard" --disk-size "30" --metadata disable-legacy-endpoints=true \
--scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
--max-pods-per-node "110" --num-nodes "1" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM \
--enable-ip-alias --network "projects/$PROJECT_ID/global/networks/default" \
--subnetwork "projects/$PROJECT_ID/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility \
--default-max-pods-per-node "110" --no-enable-master-authorized-networks \
--enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 \
--enable-shielded-nodes --node-locations "us-central1-a" --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
--workload-pool=$PROJECT_ID.svc.id.goog \
 --async

## Configure Private VPC
gcloud compute addresses create google-managed-services-default \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=20 \
    --network=projects/$PROJECT_ID/global/networks/default

gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=google-managed-services-default \
    --network=default \
    --project=$PROJECT_ID


## Create Private Postgres Cloud SQL Database
gcloud beta sql instances create $DB_INSTANCE_NAME \
    --project=$PROJECT_ID \
    --network=projects/$PROJECT_ID/global/networks/default \
    --no-assign-ip \
    --database-version=POSTGRES_12 \
    --cpu=2 \
    --memory=4GB \
    --region=$REGION \
    --root-password=${DB_INSTANCE_PASSWORD} \
    --async


echo "Checking database readiness"
while [ $(gcloud sql instances list --filter="name=$DB_INSTANCE_NAME" --format="value(STATUS)") != "RUNNABLE" ]
do
  echo "Waiting for database to be ready"
  sleep 15s
done

gcloud sql databases create ${TESTDB_NAME} --instance=${DB_INSTANCE_NAME}

gcloud sql users create ${TESTDB_USER} \
    --password=$TESTDB_PASSWORD \
    --instance=${DB_INSTANCE_NAME}


gcloud sql databases create ${PRODDB_NAME} --instance=${DB_INSTANCE_NAME}

gcloud sql users create ${PRODDB_USER} \
    --password=$PRODDB_PASSWORD \
    --instance=${DB_INSTANCE_NAME}

export DB_INSTANCE_IP=$(gcloud sql instances describe $DB_INSTANCE_NAME \
    --format=json | jq \
    --raw-output ".ipAddresses[].ipAddress")



## Connect to Private VPC
gcloud iam service-accounts create gke-db-service-account \
  --display-name="GKE DB Service Account"


gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:gke-db-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

echo "Checking Test GKE cluster readiness"
while [ $(gcloud container clusters list --filter="name=test-sec" --format="value(status)") == "PROVISIONING" ]
do
  echo "Waiting for GKE cluster to be ready"
  sleep 15s
done
gcloud container clusters get-credentials test-sec --zone="us-central1-a"



kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ksa-cloud-sql
EOF

gcloud iam service-accounts add-iam-policy-binding \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/ksa-cloud-sql]" \
  gke-db-service-account@$PROJECT_ID.iam.gserviceaccount.com


kubectl annotate serviceaccount \
  ksa-cloud-sql  \
  iam.gke.io/gcp-service-account=gke-db-service-account@$PROJECT_ID.iam.gserviceaccount.com


kubectl create secret generic gke-cloud-sql-secrets \
  --from-literal=databaseip=$DB_INSTANCE_IP \
  --from-literal=database=$TESTDB_NAME \
  --from-literal=username=$TESTDB_USER \
  --from-literal=password=$TESTDB_PASSWORD


echo "Checking Prod GKE cluster readiness"
while [ $(gcloud container clusters list --filter="name=prod-sec" --format="value(status)") == "PROVISIONING" ]
do
  echo "Waiting for GKE cluster to be ready"
  sleep 15s
done
gcloud container clusters get-credentials prod-sec --zone="us-central1-a"



kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ksa-cloud-sql
EOF

gcloud iam service-accounts add-iam-policy-binding \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/ksa-cloud-sql]" \
  gke-db-service-account@$PROJECT_ID.iam.gserviceaccount.com


kubectl annotate serviceaccount \
  ksa-cloud-sql  \
  iam.gke.io/gcp-service-account=gke-db-service-account@$PROJECT_ID.iam.gserviceaccount.com


kubectl create secret generic gke-cloud-sql-secrets \
  --from-literal=databaseip=$DB_INSTANCE_IP \
  --from-literal=database=$PRODDB_NAME \
  --from-literal=username=$PRODDB_USER \
  --from-literal=password=$PRODDB_PASSWORD


