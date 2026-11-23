resource "google_compute_network" "vpc_network" {
  name = "vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "td2-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_instance" "vm" {
  name         = "td2-vm"          # nom de la VM dans GCP
  machine_type = "e2-micro"        # petite machine, peu coûteuse
  zone         = "europe-west1-b"  # zone dans la même région que le sous-réseau

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"   # Debian 12 fournie par Google
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id

    # Bloc vide = Google attribue une IP publique (utile pour le DNS)
    access_config {}
  }
}