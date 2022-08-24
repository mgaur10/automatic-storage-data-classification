# ----------------------------------------------------------------------------------------------------------------------
# Organization policy
# ----------------------------------------------------------------------------------------------------------------------
# resource "google_project_organization_policy" "gke-vpc-peering" {
#     project = var.project_id
#     constraint = "compute.restrictVpcPeering"

#     list_policy {
#         allow {
#             all = true
#         }
#     }
# }

// Infra Modernization project
variable organization_id {
}
variable billing_account {    
}
variable folder_name {
}

variable demo_project_id {
}

variable qa_storage_bucket_name {
}

variable sens_storage_bucket_name {
}
variable nonsens_storage_bucket_name {
}
variable pubsub_topic_name {
}
variable pubsub_subscription_name {
}


# variable keyring_name {
# }

# variable crypto_key_name {
# }

# variable secret_id {
# }

# variable secert_label {
# }


# variable "ser_acc" {
#  description = " Service Account"
#  type        = string
#  default     = demo_project.project_id
# }