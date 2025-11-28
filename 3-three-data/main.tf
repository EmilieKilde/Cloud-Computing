provider "google"{
    project = "terraforming-ccc"
    region = "europe-west1"
}
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

resource "google_sql_database" "database" {
  name     = "my-database"
  instance = google_sql_database_instance.instance.name
}

# See versions at https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#database_version
resource "google_sql_database_instance" "instance" {
  name             = "my-database-instance"
  region           = "europe-west1"
  database_version = "MYSQL_8_0"

  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
  }

  deletion_protection = true
}


resource "google_cloud_run_service" "service"{
    name = "cloud-run-service"
    location = "europe-west1"

    template{
        spec{
            containers{
                image= "gcr.io/terraforming-ccc/backend-image"
            
                env{
                    name = "DB_connection"
                    value = google_sql_database_instance.instance.connection_name
                }

                env{
                    name = "DB_USER"
                    value= "root"
                }

                env{
                    name = "DB_PASSWORD"
                    value = var.db_password
                }

                env{
                    name = "DB_NAME"
                    value = google_sql_database.database.name
                }
            }
        }
    }
}

resource "google_compute_network" "vpc"{
    name = "vpc"
    auto_create_subnetworks = false
}

resource "google_compute_subnetwork""subnet" {
    name = "demo-subnet"
    ip_cidr_range = "10.0.0.0/24"
    region = "europe-west1"
    network = google_compute_network.vpc.id
}

variable "db_password" {
  type        = string
  description = "Password for the database"
  sensitive   = true
}

/*resource "google_vpc_access_connector" "connector"{
    name = "connector"
    ip_cidr_range = "10.0.1.0/28"
    network = google_compute_network.vpc.id
    min_instances = 2
    max_instances = 3
}*/
