#!/bin/bash
TF_LOG=DEBUG TF_LOG_PATH=terraform.log terraform init
terraform apply -auto-approve

# Destroy everything when done
terraform destroy -auto-approve
