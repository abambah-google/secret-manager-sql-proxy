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



output "_01_host_network_project_id" {
  value = google_project.demo_project.project_id
}

output "_02_retrieve_db_password" {
  value = "gcloud secrets versions access ${google_secret_manager_secret_version.sql_db_user_password.id} --secret ${google_secret_manager_secret.sql_db_user_password.id}"
}

output "_03_start_ssh_tunnel" {
  value = "gcloud compute ssh ${google_compute_instance.proxy_server.name} --project ${var.demo_project_id}${random_string.id.result} --zone ${var.network_zone} --tunnel-through-iap"
}

output "_04_sql_instance_connection_name" {
  value = google_sql_database_instance.private_sql_instance.connection_name
}

output "_05_initiate_sql_listner_connection" {
  value = "cloud_sql_proxy -instances=${var.demo_project_id}${random_string.id.result}:${var.network_region}:sql-instance=tcp:0.0.0.0:5432"
}

output "_06_sql_client_command" {
  value = "psql \"host=127.0.0.1 port=5432 sslmode=disable dbname=${google_sql_database.records_db.name} user=${google_sql_user.user_dev_access.name}\""
  sensitive = true
}