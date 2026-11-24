# IP publiques des VM (une par VM grâce à [*])
output "vm_public_ips" {
  description = "IP publiques des instances VM"
  value       = google_compute_instance.vm[*].network_interface[0].access_config[0].nat_ip
}

# IP privée de la base de données (dans le VPC)
output "db_private_ip" {
  description = "IP privée de la base Cloud SQL"
  value       = google_sql_database_instance.main.private_ip_address
}

# Nom DNS de l'application
output "app_dns_name" {
  description = "Nom DNS qui pointe vers les VM"
  value       = google_dns_record_set.frontend.name
}