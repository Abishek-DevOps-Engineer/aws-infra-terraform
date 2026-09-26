terraform {
  backend "s3" {
    bucket = "abishek1710-jenkinscicd-terraformbucket-01"
    key    = "path/tfstatefile/key"
    region = "ap-south-1"
  }
}
