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



# Create Folder in GCP Organization
resource "google_folder" "terraform_solution" {
  display_name =  "${var.folder_name}${random_string.id.result}"
  parent = "organizations/${var.organization_id}"
  
}

#Create the service Account
resource "google_service_account" "def_ser_acc" {
   project = google_project.demo_project.project_id
   account_id   = "sa-service-account"
   display_name = "CLoud SQL Service Account"
 }

  resource "google_project_iam_member" "cloud_sql_admin" {
    project = google_project.demo_project.project_id
    role    = "roles/cloudsql.client"
    #"roles/owner"
    member  = "serviceAccount:${google_service_account.def_ser_acc.email}"
    depends_on = [google_service_account.def_ser_acc]
  }

resource "google_project_iam_member" "cloud_sql_viewer" {
    project = google_project.demo_project.project_id
    role    = "roles/cloudsql.viewer"
    #"roles/owner"
    member  = "serviceAccount:${google_service_account.def_ser_acc.email}"
    depends_on = [google_service_account.def_ser_acc]
  }

resource "google_project_iam_member" "cloud_sql_user" {
    project = google_project.demo_project.project_id
    role    = "roles/cloudsql.instanceUser"
    #"roles/owner"
    member  = "serviceAccount:${google_service_account.def_ser_acc.email}"
    depends_on = [google_service_account.def_ser_acc]
  }




resource "google_secret_manager_secret_iam_member" "identity_password_access" {
#  for_each  = var.proxy_access_identities
  project = google_project.demo_project.project_id
  member    = var.proxy_access_identities
  role      = "roles/secretmanager.secretAccessor"
  secret_id = google_secret_manager_secret.sql_db_user_password.id
}

resource "google_service_account_iam_member" "proxy_service_account_access" {
 # for_each           = var.proxy_access_identities
  member             = var.proxy_access_identities
  role               = "roles/iam.serviceAccountUser"
  service_account_id = "${google_service_account.def_ser_acc.id}"
 # project = google_project.demo_project.project_id
}

resource "google_iap_tunnel_instance_iam_member" "id_iap_access" {
 # for_each = var.proxy_access_identities
  project = google_project.demo_project.project_id
  member   = var.proxy_access_identities
  role     = "roles/iap.tunnelResourceAccessor"
  instance = google_compute_instance.proxy_server.name
  zone     = var.network_zone
}

resource "google_compute_instance_iam_member" "oslogin_admin" {
 # for_each      = var.enable_ssh_access
 project = google_project.demo_project.project_id
  instance_name = google_compute_instance.proxy_server.name
  member        = var.enable_ssh_access
  role          = "roles/compute.osAdminLogin"
  zone   = var.network_zone    
  }

  resource "google_compute_instance_iam_member" "oslogi_admin" {
 # for_each      = var.proxy_access_identities
 project = google_project.demo_project.project_id
  instance_name = google_compute_instance.proxy_server.name
  member        = var.proxy_access_identities
  role          = "roles/compute.osAdminLogin"
  zone   = var.network_zone    
  }