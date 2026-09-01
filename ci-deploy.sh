#!/bin/bash
INVENTORY=ansible/inventory/inventory.yml
NGINX_DIR=ansible/roles/nginx

# Install ansible
apt install ansible python3

# 1. Inject SSH Key (Only triggers in CI where this variable exists)
if [ -n "$SSH_PRIVATE_KEY" ]; then
  echo "Configuring CI SSH environment..."
  mkdir -p ~/.ssh
  echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
  chmod 600 ~/.ssh/id_ed25519
fi

export ANSIBLE_HOST_KEY_CHECKING="False"

# 2. Provision Infrastructure & Fetch IP
echo "Applying Terraform..."
cd terraform
terraform init -input=false
terraform apply -auto-approve -input=false
SERVER_IP=$(terraform output -raw server_public_ip)
cd ..

# 3. Dynamic Inventory Generation
echo "Generating Ansible inventory for $SERVER_IP..."
cat <<EOF > ansible/inventory/production.ini
[webservers]
prod_server ansible_host=$SERVER_IP ansible_user=admin ansible_ssh_private_key_file=~/.ssh/id_ed25519
EOF

# 4. Deploy Configuration
echo "Running Ansible..."
cd ansible
ansible-galaxy collection install -r roles/nginx/requirements.yml
ansible-playbook -i inventory/production.ini playbooks/playbook.yml
