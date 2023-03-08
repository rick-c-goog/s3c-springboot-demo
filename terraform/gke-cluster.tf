
resource "google_container_cluster" "dev_cluster" {
  name     = "test-sec"
  count    = var.use_cloud_run ? 0 : 1 #Used to "enable" or "disable" a resource conditionally.
  location = var.region
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  enable_autopilot = true
  ip_allocation_policy {}
}

resource "google_container_cluster" "prod_sec" {
  name     = "prod-cluster"
  count    = var.use_cloud_run ? 0 : 1 #Used to "enable" or "disable" a resource conditionally. 
  location = var.region
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  enable_autopilot = true
  ip_allocation_policy {}
}
