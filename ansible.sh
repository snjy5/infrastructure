#!/bin/bash
INVENTORY=ansible/inventory/inventory.yml
NGINX_DIR=ansible/roles/nginx

apt install ansible python3

# Install Galaxy Requirements
ansible-galaxy install -fr $NGINX_DIR/requirements.yml

# Test Inventory Connectivity
ansible all -i $INVENTORY -m ping
      
# Run Main Playbook
ansible-playbook -i $INVENTORY ansible/playbooks/playbook.yml

# Verify Nginx is running
curl --fail http://localhost:8080
