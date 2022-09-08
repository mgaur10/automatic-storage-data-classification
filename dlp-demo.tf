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
  name            = "DLP Storage Classification"
  billing_account = var.billing_account
  folder_id = google_folder.terraform_solution.name
  depends_on = [
      google_folder.terraform_solution
  ]
}

# Enable the necessary API services
resource "google_project_service" "api_service" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "dlp.googleapis.com",
    "cloudfunctions.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com"
  ])

  service = each.key

  project            = google_project.demo_project.project_id
  disable_on_destroy = true
  disable_dependent_services = true
}

resource "time_sleep" "wait_120_seconds_enable_service_api" {
  depends_on = [google_project_service.api_service]
  create_duration = "120s"
}

#Create storage buckets

resource "google_storage_bucket" "cloud_qa_storage_bucket_name" {
  name          = "${var.qa_storage_bucket_name}${random_string.id.result}"
  location      = "us-central1"
  force_destroy = true
  project       = google_project.demo_project.project_id
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "cloud_sens_storage_bucket_name" {
  name          = "${var.sens_storage_bucket_name}${random_string.id.result}"
  location      = "us-central1"
  force_destroy = true
  project       = google_project.demo_project.project_id
  uniform_bucket_level_access = true
}


resource "google_storage_bucket" "cloud_nonsens_storage_bucket_name" {
  name          = "${var.nonsens_storage_bucket_name}${random_string.id.result}"
  location      = "us-central1"
  force_destroy = true
  project       = google_project.demo_project.project_id
  uniform_bucket_level_access = true
}

# Creates zip file of function code & requirments.txt
data "archive_file" "source" {
    type        = "zip"
    source_dir  = "${path.module}/application"
    output_path = "${path.module}/dlpfunction.zip"
}

#Creating the bucket for python source code
resource "google_storage_bucket" "application" {
  name     = "application-${var.demo_project_id}${random_string.id.result}"
  location      = "us-central1"
  force_destroy = true
  project       = google_project.demo_project.project_id
  uniform_bucket_level_access = true
}

# Add zip file to the Cloud Function's source code bucket
resource "google_storage_bucket_object" "python_code" {
  name   = "dlpfunction.zip"
  bucket = google_storage_bucket.application.name
  source = "${path.module}/dlpfunction.zip"
}

resource "google_pubsub_topic" "pubsub_topic" {
  name = var.pubsub_topic_name
  project = google_project.demo_project.project_id
  }

resource "google_pubsub_subscription" "pubsub_subscription" {
  name  = var.pubsub_subscription_name
  project = google_project.demo_project.project_id
  topic = google_pubsub_topic.pubsub_topic.name
  
}

# Create the DLP Functions
resource "google_cloudfunctions_function" "create_DLP_job" {
  name        = "create_DLP_job"
  description = "Create DLP Job"
  runtime     = "python37"
  project     = google_project.demo_project.project_id
  region      = "us-central1"
  ingress_settings = "ALLOW_INTERNAL_AND_GCLB"
  


  available_memory_mb   = 512
  source_archive_bucket = google_storage_bucket.application.name
  source_archive_object = google_storage_bucket_object.python_code.name
   entry_point           = "create_DLP_job"
  service_account_email = "${google_service_account.def_ser_acc.email}"
  


  event_trigger {
        event_type = "google.storage.object.finalize"
        resource   = "${var.qa_storage_bucket_name}${random_string.id.result}"  # quarantine bucket where files are uploaded for processing
    }

  depends_on = [time_sleep.wait_120_seconds_enable_service_api]

  environment_variables = {
    PROJ_ID      = google_project.demo_project.project_id
    QA_BUCKET    = google_storage_bucket.cloud_qa_storage_bucket_name.name
    SENS_BUCKET  = google_storage_bucket.cloud_sens_storage_bucket_name.name
    NONS_BUCKET  = google_storage_bucket.cloud_nonsens_storage_bucket_name.name
    PB_SB_TOP    = var.pubsub_topic_name
  }
}

resource "google_cloudfunctions_function" "resolve_DLP" {
  name        = "resolve_DLP"
  description = "Resolve DLP"
  runtime     = "python37"
  project     = google_project.demo_project.project_id
  region      = "us-central1"
  ingress_settings = "ALLOW_INTERNAL_AND_GCLB"
  
  available_memory_mb   = 512
  source_archive_bucket = google_storage_bucket.application.name
  source_archive_object = google_storage_bucket_object.python_code.name
  entry_point           = "resolve_DLP"
  service_account_email = "${google_service_account.def_ser_acc.email}"
  
    event_trigger {
        event_type = "google.pubsub.topic.publish"
        resource   = "projects/${var.demo_project_id}${random_string.id.result}/topics/${var.pubsub_topic_name}"   
    }
  

  depends_on = [time_sleep.wait_120_seconds_enable_service_api]

  environment_variables = {
   PROJ_ID      = google_project.demo_project.project_id
    QA_BUCKET    = google_storage_bucket.cloud_qa_storage_bucket_name.name
    SENS_BUCKET  = google_storage_bucket.cloud_sens_storage_bucket_name.name
    NONS_BUCKET  = google_storage_bucket.cloud_nonsens_storage_bucket_name.name
    PB_SB_TOP    = var.pubsub_topic_name
     }
}
