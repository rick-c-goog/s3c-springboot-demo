
# Create an IP address
resource "google_compute_global_address" "global_ip_alloc" {
  name          = "google-managed-services-default"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = "default"
}

# Create a private connection
resource "google_service_networking_connection" "worker_pool_conn" {
  network                 = "default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.global_ip_alloc.name]
}
