provider "google" {
}

provider "google" {
    alias = "service"
    impersonate_service_account = google_service_account.def_ser_acc.email
      region  = "us-central1"
  zone    = "us-central1-c"
}