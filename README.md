# Demo

This demo covers the Software Delivery Shield features such as Cloud Workstations, Cloud Code Source Protect, Vulnerability Scanning, Signing, and Binary Authorization.

**Acknowledgements:** This repository is based on Victor Szalvay's https://github.com/vszal/secure-cicd-maven

## Demo Setup
### Create a project
* Create a Google Cloud project and provide all [permissions for GKE setup](https://raw.githubusercontent.com/slsa-demo/tkn-binauth/main/arg_k8s_perms.sh?token=GHSAT0AAAAAABPJH2IFVGFOEYWPGGN6IVFOY57FFAA) if running on argolis. 

* Set PROJECT_ID
```
export PROJECT_ID=$(gcloud config get project)
```

### Download the bootstrap scripts from this repo

Clone this demo repo. This will download all the scripts you need to run to setup infrastructure for the demo.

```
git clone https://github.com/VeerMuchandi/s3c-springboot-demo
cd s3c-springboot-demo
```

### Create Container Registry and Cloud Deploy pipeline
The following script enables all needed APIs and deploy the pipeline

```
./bootstrap/init.sh
```
Verify that the Google Cloud Deploy pipeline is created in the [console](https://console.cloud.google.com/deploy/delivery-pipelines).

Also notice that the artifact registry with name `maven-demo-app` is created and the automatic vulnerability scanning is turned on from the [console](https://console.cloud.google.com/artifacts).

### Fork the source code git repo
We will use a spring boot application in this demo. The source code is in a separate repository. [Fork the source code repo on Github](https://github.com/VeerMuchandi/sbcrudapp)



### Connect forked repository to Cloud Build 
This is a manual step to be handled via [Console](https://console.cloud.google.com/cloud-build). 

Connect the forked GitHub repository to Cloud Build for the `global` region, following the [steps here](https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github)

### Standup GKE clusters

This script creates two GKE clusters with names `test-sec` and `prod-sec` and two databases for test and prod. More GKE clusters can be added. The `clouddeploy.yaml` file should be updated accordingly.

```
./bootstrap/add_gke_clusters_dbs.sh
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
./bootstrap/add-signing-keys.sh
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
./bootstrap/setup_cloudbuild.sh
```
### Set up your IDE and Source Code

### Install Cloud Workstations

This demo will showcase Cloud Workstations as the IDE. If you already have Cloud Workstations cluster installed somewhere (it doesnt have to be in this project) you can use it. Otherwise you can set up [cloud workstation configuration](https://cloud.google.com/workstations/docs/create-configuration) and start a [workstation instance](https://cloud.google.com/workstations/docs/create-workstation). 

If you are creating a new Cloud Workstation cluster it takes 10 mins to stand up a new cluster.

* Launch your workstation instance as explained [here](https://cloud.google.com/workstations/docs/create-workstation#launch_your_workstation).

* On the status bar at the bottom of the window, click on `Connect to Google Cloud`, click the link to authenticate with your credentials. 

* On the status bar, click on `Select Project` and choose the above project represented by PROJECT_ID above. This way you can use a cloud workstation (even if preexisting in a different project) to work with this demo.   

#### Install a few useful extensions and tools

Open a terminal and install the following useful tools and extensions.

* Tools jq, httpie and gettext-base
```
sudo apt install -y gettext-base jq httpie
```
* Java Extension Pack
```
wget https://open-vsx.org/api/vscjava/vscode-java-pack/0.25.0/file/vscjava.vscode-java-pack-0.25.0.vsix
code-oss-cloud-workstations --install-extension vscjava.vscode-java-pack-0.25.0.vsix
```
* Java Debug
```
wget https://open-vsx.org/api/vscjava/vscode-java-debug/0.47.0/file/vscjava.vscode-java-debug-0.47.0.vsix
code-oss-cloud-workstations --install-extension vscjava.vscode-java-debug-0.47.0.vsix
```
* Java Language Support
```
wget https://open-vsx.org/api/redhat/java/linux-x64/1.13.0/file/redhat.java-1.13.0@linux-x64.vsix
code-oss-cloud-workstations --install-extension redhat.java-1.13.0@linux-x64.vsix
```
#### Download Cloud Code Source Protect extension

This extension is in private preview at the time of writing this document, and you need to request access as explained [here](https://cloud.google.com/software-supply-chain-security/docs/safeguard-source#:~:text=Cloud%20Code%20source%20protect%20(Preview)&text=Cloud%20Code%20source%20protect%20gives,they%20work%20in%20their%20IDEs) or visit this [internal link](go/cc-s3c-ext) and follow the instructions to install Cloud Code Source Protect extension.

**Tips:** 
* To upload the vsix extension (files) to the workstation instance, go to explorer view, open a folder and then right click in the explorer to **Upload** file from your local machine.

#### Download your forked repo into your Workstation instance

```
git clone REPLACE_YOUR_FORKED_CODEREPO
```
#### Configure git username and email on the workstation
```
git config --global user.name "John Doe"
git config --global user.email johndoe@example.com
```

## Steps to Demo

1. Open the Workstation instance and the forked source code.
`File`->`Open Folder` and select your forked git repository folder. Once the repo is open in the explorer, you will notice two folders with names `bad` and `good`. The `bad` folder contains pom.xml file with vulnerabilites and also the `vulnz-signing-policy`. Copy that to the root of the repository.
2. Show the issues pointed by the Cloud Code Source Protect. Explain how Cloud Code Source Protect identifies issues with transitive dependencies. Fix a couple of issues by importing right dependencies. Don'f fix all the issues and commit and push the changes to the Git repo. 
3. Show how the `cloudbuild.yaml` uses kritis signer to run signing based on the `vulnz-signing-policy` as in the snippet below 
```
- name: gcr.io/$PROJECT_ID/kritis-signer
    entrypoint: /bin/bash
    args:
    - -c
    - |
      /kritis/signer \
      -v=10 \
      -alsologtostderr \
      -image=$(/bin/cat image-digest.txt) \
      -policy=./vulnz-signing-policy.yaml \
      -kms_key_name=${_KMS_KEY_NAME} \
      -kms_digest_alg=${_KMS_DIGEST_ALG} \
      -note_name=${_NOTE_NAME}
    waitFor: ['push']
``` 
Walk through the `vulnz-signing-policy` file in the workstation to show how the `spec` allows choosing severity levels and allow listing specific CVEs as in the code snippet below:

```
spec:
  imageVulnerabilityRequirements:
    maximumFixableSeverity: MEDIUM
    maximumUnfixableSeverity: LOW
    allowlistCVEs:
    - projects/goog-vulnz/notes/CVE-2022-43680
```

4. Commit the repository. Since you configured the build trigger, it will trigger a build as soon as you push the changes to Git repo. You can watch the build running via [console](console.cloud.google.com/cloud-build/builds) and show how the build fails at the signing step. Look at the build logs for the `vulnsign` step to see how the some critical and high vulnerabilities were discovered during container scanning as under:

```
E0112 18:31:51.268507       1 main.go:209] Found 9 violations in image us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f:
E0112 18:31:51.268536       1 main.go:211] found fixable CVE projects/goog-vulnz/notes/CVE-2022-22965 in us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f, which has severity CRITICAL exceeding max fixable severity MEDIUM
E0112 18:31:51.268566       1 main.go:211] found fixable CVE projects/goog-vulnz/notes/CVE-2022-42003 in us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f, which has severity HIGH exceeding max fixable severity MEDIUM
E0112 18:31:51.268576       1 main.go:211] found fixable CVE projects/goog-vulnz/notes/CVE-2022-22968 in us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f, which has severity HIGH exceeding max fixable severity MEDIUM
E0112 18:31:51.268584       1 main.go:211] found fixable CVE projects/goog-vulnz/notes/CVE-2022-31197 in us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f, which has severity HIGH exceeding max fixable severity MEDIUM
E0112 18:31:51.268593       1 main.go:211] found unfixable CVE projects/goog-vulnz/notes/CVE-2022-42898 in us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f, which has severity MEDIUM exceeding max unfixable severity LOW
E0112 18:31:51.268604       1 main.go:211] found fixable CVE projects/goog-vulnz/notes/CVE-2022-22970 in us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f, which has severity HIGH exceeding max fixable severity MEDIUM
E0112 18:31:51.268612       1 main.go:211] found fixable CVE projects/goog-vulnz/notes/CVE-2022-42004 in us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f, which has severity HIGH exceeding max fixable severity MEDIUM
E0112 18:31:51.268622       1 main.go:211] found fixable CVE projects/goog-vulnz/notes/CVE-2022-21724 in us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f, which has severity HIGH exceeding max fixable severity MEDIUM
E0112 18:31:51.268632       1 main.go:211] found fixable CVE projects/goog-vulnz/notes/CVE-2020-36518 in us-central1-docker.pkg.dev/secure-s3c-mvn3/maven-demo-app/myspringbootapp@sha256:c98e9694ee5a28ccb4beee5956bba77d1d627044329ab05693358fd98d70f62f, which has severity HIGH exceeding max fixable severity MEDIUM
```
Explain that even if a developer did not fix the issues, how these issues would be caught as part of pipeline through container scanning.

5. Now replace with the good `pom.xml` file which has all the fixes (CAUTION: the CVEs keep changing, so you may have to try this out during preparation and add additional fixes. If certain CVEs dont have fixes add them to the Allow list!!). This time the build should be successful and the signing should be complete. Show the successful Cloud Build run in the [console](console.cloud.google.com/cloud-build/builds).
6. Once the build is complete, it triggers deployment using Cloud Deploy. Navigate to [Cloud Deploy on Console](https://console.cloud.google.com/deploy/delivery-pipelines) to show how the deployment progresses on the test cluster.
7. Show the [binauth policy on the Test Cluster](https://console.cloud.google.com/security/binary-authorization/policy). It accepts only images created via cloud build. Optionally, try deploying a random container and it should fail.
8. Navigate to [Artifact Registry on the console](https://console.cloud.google.com/artifacts/docker) and show the latest image that is created. Also look at the vulnerabilities identified by the automatic scanner that runs on the Artifact registry.
9. Navigate to the [Kubernetes Workloads on the console](https://console.cloud.google.com/kubernetes/workload/overview) and show the running application in the Test cluster. 
10. Navigate back to [Cloud Deploy on Console](https://console.cloud.google.com/deploy/delivery-pipelines) and promote to the next environment. Show the manual approval process as a gate before deploying this application to production. Review and approve the production deployment.
11. Deploy to production and show the success.
12. Navigate to security posture of [Kubernetes console](https://console.cloud.google.com/kubernetes/security) and show the configurations and vulnerabilites identified at runtime. This is to show how the runtimes are continuously monitored to identify any security issues that may come up after deployment.













