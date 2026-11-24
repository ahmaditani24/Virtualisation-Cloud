resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "td2-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_instance" "vm" {
  count        = 2
  name         = "td2-vm-${count.index}" # nom de la VM dans GCP
  machine_type = "e2-micro"              # petite machine, peu coûteuse
  zone         = "europe-west1-b"        # zone dans la même région que le sous-réseau

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" # Debian 12 fournie par Google
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id

    # Bloc vide = Google attribue une IP publique (utile pour le DNS)
    access_config {}
  }
}

# ① Plage d'IP réservée dans notre VPC pour les services Google
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

# ② Pont (peering) entre notre VPC et le réseau de Google
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# ③ Base Cloud SQL avec une IP privée dans notre VPC
resource "google_sql_database_instance" "main" {
  name                = "main-db-instance"
  database_version    = "MYSQL_8_0"
  region              = "europe-west1"
  deletion_protection = false

  # Dépendance EXPLICITE : le pont doit exister avant la base
  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false                                 # pas d'IP publique
      private_network = google_compute_network.vpc_network.id # dans NOTRE VPC
    }
  }
}


resource "google_dns_record_set" "frontend" {
  name = "frontend.${google_dns_managed_zone.prod.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.prod.name

  rrdatas = google_compute_instance.vm[*].network_interface[0].access_config[0].nat_ip
}

resource "google_dns_managed_zone" "prod" {
  name     = "prod-zone"
  dns_name = "prod.mydomain.com."
}
