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




variable organization_id {
}
variable billing_account {    
}
variable folder_name {
}

variable demo_project_id {
}

variable vpc_network_name {
}




 variable network_zone{

 }

variable "cloud_sql_proxy_version" {
  description = "Which version to use of the Cloud SQL proxy."
  type        = string
  default     = "v1.31.1"
}



variable "proxy_access_identities" {
  description = "List of identities who require access to the SQL proxy, and database.  Every identity should be prefixed with the type, for example user:, serviceAccount: and/or group:"
  type        = string
  default     = "user:admin@manishkgaur.altostrat.com"
}


variable "enable_ssh_access" {
  description = "Allow SSH access to the VM.  This will enable SSH access for all identities, so be careful when enabling this."
  type        = string
  default     = "user:admin@manishkgaur.altostrat.com"
}

 variable network_region {
    
 }