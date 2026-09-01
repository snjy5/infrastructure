#!/bin/bash

apply() {
  terraform init
  terraform apply
}

destroy() {
  echo "WARNING: If 'prevent_destroy = true' is still in main.tf, this will fail."
  terraform destroy
}

# Check if a command was passed
if [ -z "$1" ]; then
  echo "Error: No command specified."
  echo "Usage: ./script.sh {apply|destroy}"
  exit 1
fi

# Execute the function passed as the first argument
"$1"
