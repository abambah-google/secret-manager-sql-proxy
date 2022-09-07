/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */



# Random id for naming
resource "random_string" "id" {
  length = 4
  upper   = false
  lower   = true
  number  = true
  special = false
 }

# Create the Project
resource "google_project" "demo_project" {
  project_id      = "${var.demo_project_id}${random_string.id.result}"
  name            = "Secret Manager Demo"
  billing_account = var.billing_account
  folder_id = google_folder.terraform_solution.name
  depends_on = [
      google_folder.terraform_solution
  ]
}

# Enable the necessary API services
resource "google_project_service" "api_service" {
  for_each = toset([
     "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
    "secretmanager.googleapis.com",
    "iap.googleapis.com"

  ])

  service = each.key

  project            = google_project.demo_project.project_id
  disable_on_destroy = true
  disable_dependent_services = true
}

resource "time_sleep" "wait_60_seconds_enable_service_api" {
  depends_on = [google_project_service.api_service]
  create_duration = "60s"
}

# Create the host network

resource "google_compute_network" "host_network" {
  project                 = google_project.demo_project.project_id
  name                    = var.vpc_network_name
  auto_create_subnetworks = false
  description             = "Host network for the Cloud SQL instance and proxy"
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}

# Create SQL Subnetwork

resource "google_compute_subnetwork" "sql_subnetwork" {
  name          = "host-network-${var.network_region}"
  ip_cidr_range = "192.168.10.0/24"
  region        = var.network_region
  project = google_project.demo_project.project_id
  network       = google_compute_network.host_network.self_link
  private_ip_google_access   = true 
  depends_on = [
    google_compute_network.host_network,
    
  ]
}



# Setup Private IP access

resource "google_compute_global_address" "sql_instance_private_ip" {
  name          = "sql-private-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.host_network.id
  project = google_project.demo_project.project_id
  description = "Cloud SQL IP Range"
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]  
}
# Create Private Connection:
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.host_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_instance_private_ip.name]
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}

# Create DB Instance
resource "google_sql_database_instance" "private_sql_instance" {
  project = google_project.demo_project.project_id

#  project             = module.cloud_sql_proxy_service_project.project_id
  deletion_protection = false
  name                = "sql-instance"
  region              = var.network_region

  database_version    = "POSTGRES_11"

  settings {
    tier              = "db-f1-micro"
    disk_size         = 10
    disk_type         = "PD_SSD"
    availability_type = "REGIONAL"

    backup_configuration {
      binary_log_enabled = false
      enabled            = true
    }

    ip_configuration {
      private_network = google_compute_network.host_network.id
      require_ssl     = true
      ipv4_enabled    = false
    }
  }

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    time_sleep.wait_60_seconds_enable_service_api,
  ]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}



resource "google_sql_database" "records_db" {
  project = google_project.demo_project.project_id
  instance = google_sql_database_instance.private_sql_instance.name
  name     = "records"
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}

resource "google_sql_user" "user_dev_access" {
  project = google_project.demo_project.project_id
  instance = google_sql_database_instance.private_sql_instance.name
  name     = random_password.db_user_name.result
  password = random_password.db_user_password.result
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}

resource "random_password" "db_user_password" {
  length      = 15
  min_lower   = 3
  min_numeric = 3
  min_special = 5
  min_upper   = 3
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}

resource "random_password" "db_user_name" {
  length      = 8
  min_lower   = 8
 
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}

resource "google_secret_manager_secret" "sql_db_user_password" {
  project = google_project.demo_project.project_id
  secret_id = "sql-db-password"
  replication {
    automatic = true
  }
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}

resource "google_secret_manager_secret_version" "sql_db_user_password" {
  secret      = google_secret_manager_secret.sql_db_user_password.id
  secret_data = random_password.db_user_password.result
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}


resource "google_secret_manager_secret" "sql_db_user_name" {
  project = google_project.demo_project.project_id
  secret_id = "sql-db-uname"
  replication {
    automatic = true
  }
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}

resource "google_secret_manager_secret_version" "sql_db_user_name" {
  secret      = google_secret_manager_secret.sql_db_user_name.id
  secret_data = random_password.db_user_name.result
  depends_on = [time_sleep.wait_60_seconds_enable_service_api]
}



resource "google_compute_firewall" "allow_http_icmp" {
name = "allow-http-icmp"
network = google_compute_network.host_network.self_link
project = google_project.demo_project.project_id
direction = "INGRESS"
allow {
    protocol = "tcp"
    ports    = ["5432"]
    }
 source_ranges = ["35.235.240.0/20"]
target_service_accounts = [
    google_service_account.def_ser_acc.email
  ]
allow {
    protocol = "icmp"
    }
    depends_on = [
        google_compute_network.host_network
    ]
}


resource "google_compute_firewall" "allow_iap_proxy" {
name = "allow-iap-proxy"
network = google_compute_network.host_network.self_link
project = google_project.demo_project.project_id
direction = "INGRESS"
allow {
    protocol = "tcp"
    ports    = ["22","5432"]
    }
source_ranges = ["35.235.240.0/20"]
target_service_accounts = [
    google_service_account.def_ser_acc.email
  ]
    depends_on = [
        google_compute_network.host_network
    ]
}


# Create Proxy Server Instance
resource "google_compute_instance" "proxy_server" {
  project = google_project.demo_project.project_id
  name         = "proxy-server"
  machine_type = "n2-standard-4"
  zone         = var.network_zone

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  depends_on = [
    time_sleep.wait_60_seconds_enable_service_api,
    google_compute_router_nat.nats,
    # null_resource.chmod_execute_sql_install_script
    ]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
 }

  network_interface {
    network = google_compute_network.host_network.self_link
    subnetwork = google_compute_subnetwork.sql_subnetwork.self_link
   
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.def_ser_acc.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = "sudo apt-get update -y;sudo apt-get install -y wget curl;wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy;chmod +x cloud_sql_proxy;sudo apt-get install postgresql-client -y;mv cloud_sql_proxy /usr/local/bin"

  #metadata = {

   # startup-script = local_file.sql_proxy_install_script.content
    #enable-oslogin = "TRUE"
  #}
}



# Create a CloudRouter
resource "google_compute_router" "router" {
  project = google_project.demo_project.project_id
  name    = "subnet-router"
  region  = google_compute_subnetwork.sql_subnetwork.region
  network = google_compute_network.host_network.id

  bgp {
    asn = 64514
  }
}

# Configure a CloudNAT
resource "google_compute_router_nat" "nats" {
  project = google_project.demo_project.project_id
  name                               = "nat-cloud-sql-${var.vpc_network_name}"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
  depends_on = [google_compute_router.router]
}

