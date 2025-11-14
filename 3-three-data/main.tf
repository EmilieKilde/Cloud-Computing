provider "google"{
    project = "terraforming-ccc"
    region = "europe-west1"
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
  settings {
    tier = "db-f1-micro"
  
    ip_configuration {
        ipv4_enabled = false
        private_network = google_compute_network.main_vpc.id
    }
  }
  deletion_protection  = true
}

resource "google_cloud_run_service" "service"{
    name = "cloud-run-service"
    location = "europe-west1"

    template{
        spec{
            containers{
                image= "gcr.io/terraforming-ccc/my-backend-image"
            
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
            vpc_access {
                connector = google_vpc_access_connector.connector.name
                egress = "PRIVATE_RANGES_ONLY"
            }
        }
    }
}

resource "google_compute_network" "vpc"{
    name = "demo-vpc"
    auto_create_subnetworks = false
}