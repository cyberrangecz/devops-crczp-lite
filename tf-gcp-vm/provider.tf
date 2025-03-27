provider "google" {
  credentials = file("auth.json")

  project = "crczp-lite"
  region  = "europe-west3"
  zone    = "europe-west3-c"
}
