/******************************************
1.  Build Kritis Image
 *****************************************/
resource "null_resource" "build_kritis" {
  provisioner "local-exec" {
    command = <<-EOT
      git clone https://github.com/grafeas/kritis.git
      cd kritis
      gcloud builds submit . --config deploy/kritis-signer/cloudbuild.yaml

  EOT
  }
}


resource "google_kms_key_ring" "keyring" {
  name     = "binauthz"
  location = "${var.region}"
  project = "${var.project_id}"
}

resource "google_kms_crypto_key" "vulnz-key" {
  name     = "vulnz-signer"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "rsa-sign-pkcs1-2048-sha256"
  }

  lifecycle {
    prevent_destroy = true
  }
}
resource "google_container_analysis_note" "vulnz-note" {
  name = "vulnz-note"
  attestation_authority {
    hint {
      human_readable_name = "Vulnerability scan not"
    }
  }
}

resource "google_binary_authorization_attestor" "vulnz-attestor" {
  name = "vulnz-attestor"
  project = var.project_id
  attestation_authority_note {
    note_reference = google_container_analysis_note.vulnz-note.name
    public_keys {
      id = data.google_kms_crypto_key_version.vulnz-version.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.vulnz-version.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.vulnz-version.public_key[0].algorithm
      }
    }
  }
}

data "google_kms_crypto_key_version" "vulnz-version" {
  crypto_key = google_kms_crypto_key.vulnz-key.id
}


module "project-iam-bindings" {
  source   = "terraform-google-modules/iam/google//modules/projects_iam"
  projects = [var.project_id]
  mode     = "additive"

  bindings = {
    "roles/containeranalysis.notes.occurrences.viewer" = [
      "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
    ]
    "roles/containeranalysis.notes.attacher" = [
      "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
      
    ]
  }
}



resource "google_binary_authorization_attestor_iam_binding" "vulnz-viewer-binding" {
  project = var.project_id
  attestor = google_binary_authorization_attestor.vulnz-attestor.name
  role = "roles/binaryauthorization.attestorsViewer"
  members = [
    "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
  ]
}

resource "google_kms_key_ring_iam_binding" "key_ring" {
  key_ring_id = google_kms_key_ring.keyring.id
  role        = "roles/cloudkms.signerVerifier"
  
  members = [
    "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
  ]
}


resource "google_binary_authorization_policy" "test-policy" {
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }

  default_admission_rule {
    evaluation_mode  = "ALWAYS_ALLOW"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }

  cluster_admission_rules {
    cluster                 = "${var.zone}.test-sec"
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.vulnz-attestor.name]
  }
}

resource "google_binary_authorization_policy" "prod-policy" {
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }

  default_admission_rule {
    evaluation_mode  = "ALWAYS_ALLOW"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }

  cluster_admission_rules {
    cluster                 = "${var.zone}.prod-sec"
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.vulnz-attestor.name, google_binary_authorization_attestor.qa-attestor.name]
  }
}



resource "google_kms_crypto_key" "qa-key" {
  name     = "qa-signer"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "rsa-sign-pkcs1-2048-sha256"
  }

  lifecycle {
    prevent_destroy = true
  }
}
resource "google_container_analysis_note" "qa-note" {
  name = "qa-note"
  attestation_authority {
    hint {
      human_readable_name = "Vulnerability scan note"
    }
  }
}

resource "google_binary_authorization_attestor" "qa-attestor" {
  name = "qa-attestor"
  project = var.project_id
  attestation_authority_note {
    note_reference = google_container_analysis_note.qa-note.name
    public_keys {
      id = data.google_kms_crypto_key_version.qa-version.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.vulnz-version.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.vulnz-version.public_key[0].algorithm
      }
    }
  }
}

data "google_kms_crypto_key_version" "qa-version" {
  crypto_key = google_kms_crypto_key.qa-key.id
}




resource "google_binary_authorization_attestor_iam_binding" "qa-viewer-binding" {
  project = var.project_id
  attestor = google_binary_authorization_attestor.qa-attestor.name
  role = "roles/binaryauthorization.attestorsViewer"
  members = [
    "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
  ]
}






