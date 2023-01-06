# Demo

This demo covers the Software Delivery Shield features such as Cloud Workstations, Cloud Code Source Protect, Vulnerability Scanning, Signing, and Binary Authorization.

**Acknowledgements:** This repository is based on Victor Szalvay's https://github.com/vszal/secure-cicd-maven

## Demo Setup
### Create a project
* Create a Google Cloud project and provide all permissions for GKE setup. 
* Set PROJECT_ID
```
export PROJECT_ID=$(gcloud config get project)
```

### Create Container Registry and Cloud Deploy pipeline
The following script enables all needed APIs and deploy the pipeline

```
. ./bootstrap/init.sh
```
Verify that the Google Cloud Deploy pipeline is created in the [console](https://console.cloud.google.com/deploy/delivery-pipelines).

Also notice that the artifact registry with name `maven-demo-app` is created and the automatic vulnerability scanning is turned on from the [console](https://console.cloud.google.com/artifacts).

### Fork the source code git repo
[Fork this source code repo on Github](https://github.com/VeerMuchandi/sbcrudapp)

### Set up your IDE and Source Code

#### Install Cloud Workstations
TBD

#### Create a workstation
TBD

#### Download Cloud Code Source Protect extension
TBD

#### Download your forked repo into your Workstation instance
TBD

### Connect repository to Cloud Build 
This is a manual step to be handled via [Console](https://console.cloud.google.com/cloud-build). 

Connect the GitHub repository to Cloud Build for the `global` region, following the [steps here](https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github)

### Standup GKE clusters

This script creates two GKE clusters with names `test-sec` and `prod-sec` and two databases for test and prod. More GKE clusters can be added. The `clouddeploy.yaml` file should be updated accordingly.

```
. ./bootstrap/add_gke_clusters_dbs.sh
```

### Set up Kritis Signer

```
pushd .
cd ..
git clone https://github.com/grafeas/kritis.git
cd kritis

#build and push the kritis signer image to gcr.io in the project
gcloud builds submit . --config deploy/kritis-signer/cloudbuild.yaml
popd
```

### Add signing Keys

Run the following script to create a key ring, add signing keys for vulnerability signer, add a note, attestor and required permissions.

```
. ./bootstrap/add-signing-keys.sh
```

Verify that your new attestor appears in the [console UI](https://console.cloud.google.com/security/binary-authorization/attestors). You will see two attestors

* built-by-cloud-build (system generated)
* vulnz-attestor(attestor added by the script above)

### Setup Binary Authorization policy

```
gcloud container binauthz policy import policy/binauthz/attestor-policy.yaml
```
Verify the policy is created from the [console UI](https://console.cloud.google.com/security/binary-authorization/policy)

### Setup Cloud Build

The following script will create a cloudbuild trigger connecting to the forked GitHub repository. It will also create private pool and provide necessary IAM access to the service account to be able to run container analysis, attach notes etc.

```
. ./bootstrap/setup_cloudbuild.yaml
```

## Steps to Demo

1. Open the Workstation instance and the forked source code. You will notice two folders with names `bad` and `good`. The `bad` folder contains pom.xml file with vulnerabilites and also the `vulnz-signing-policy`. Copy that to the root of the repository.
2. Show the issues pointed by the Cloud Code Source Protect. Explain how Cloud Code Source Protect identifies issues with transitive dependencies. Fix a couple of issues by importing right dependencies. Don'f fix all the issues.
3. Show how the `cloudbuild.yaml` uses kritis signer to run signing based on the `vulnz-signing-policy`. Walk through the file to show how the `spec` allows choosing severity levels and allow listing specific CVEs.
4. Commit the repository. Since CloudBuild trigger was setup, it will start cloud build. Navigate to CloudBuild console and show how the build fails at the signing step.
5. Now replace with the good `pom.xml` file which has all the fixes (CAUTION: the CVEs keep changing, so you may have to try this out during preparation and add additional fixes. If certain CVEs dont have fixes add them to the Allow list!!). This time the build should be successful and the signing should be complete. 
6. Once the build is complete, it triggers deployment using Cloud Deploy. Navigate to Cloud Deploy on Console to show the same.
7. Show the binauth policy on the Test Cluster. It accepts only images created via cloud build. Optionally, try deploying a random container and it should fail.
8. Show the running application in the Test cluster. 
9. Promote to the next environment. Show the manual approval process as a gate before deploying to production.
10. Deploy to production and show the success.













