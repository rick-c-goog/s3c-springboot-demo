
# Create an IP address
resource "google_compute_global_address" "global_ip_alloc" {
  name          = "google-managed-services-default"
  purpose       = "VPC_PEERING"
  address_type  = "global"
  prefix_length = 20
  network       = "default"
}

# Create a private connection
resource "google_service_networking_connection" "default" {
  network                 = "default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.global_ip_alloc.name]
}
