# Infrastructure Automation Wiki & Operations Guide

This repository is designed as a modular toolkit. You can deploy the entire stack top-to-bottom, or rip out individual components to use in your own projects. Follow the standards below to maintain security and clean architecture when extending the codebase.

---

## 1. Quick Start & Modular Execution

You do not have to deploy everything at once. The infrastructure is decoupled so you can run tools in isolation.

### A. Provisioning Hardware (Terraform)
To spin up the base AWS infrastructure (EC2 + Elastic IP) independently of the software configuration:
```bash
cd terraform/
./tf.sh apply
```

Note: If running manually, copy the output IP address and update ansible/inventory/production.ini before running Ansible.
B. Running Ansible Roles in Isolation
If you only want to update Nginx without touching Docker, Gitea, or WireGuard, you can execute a single role. (Note: To use this, append tags: ['role_name'] to the role definitions in your playbook.yml):
# Run only the Nginx and Firewall configuration
ansible-playbook -i ansible/inventory/production.ini ansible/playbooks/playbook.yml --tags "nginx,firewall"

C. Hacking & Customizing
Treat this repository like a wiki. If you only want to extract the WireGuard VPN for a different server:
 * Delete the terraform/ directory.
 * Delete all roles in ansible/roles/ except wireguard and firewall.
 * Remove the deleted roles from ansible/playbooks/playbook.yml.
 * Update ansible/roles/wireguard/defaults/main.yml with your preferred subnets and run it against your own inventory.
2. Core Development Standards
If you are contributing or extending the permanent stack, these rules are mandatory:
 * Idempotency is Mandatory: Every task must be safely repeatable. Use creates, removes, or changed_when directives for shell commands to prevent them from executing on every run.
 * Service Restarts: Never use the service module inline to restart services after configuration changes. Always use notify: <Handler Name> and define the trigger in the role's handlers/main.yml.
 * Variable Management: Never hardcode IPs, domains, or credentials in tasks/main.yml. Define them in defaults/main.yml and override them in ansible/inventory/production.ini or an encrypted Ansible Vault.
 * Local Binding: Any newly containerized service must bind its exposed ports strictly to 127.0.0.1 (e.g., Gitea mapping to 127.0.0.1:3000). Never expose backend application ports directly to the public internet.
3. Adding a New Service (Step-by-Step)
To deploy a new application (e.g., a Node.js backend, a monitoring stack, or a new database), follow this exact flow:
 * Create the Role:
   Run ansible-galaxy role init ansible/roles/<new_service> to generate the standard directory structure.
 * Write the Deployment Tasks:
   Use the community.docker.docker_compose_v2 module for containerized workloads. Ensure volume paths map to persistent directories on the host (e.g., /opt/<new_service>_data).
 * Expose via Nginx (Reverse Proxy):
   Do not open the application's port in the firewall. Instead, update the Nginx configuration template (ansible/roles/nginx/templates/proxy_loadbalancer.conf.j2) by adding a new upstream block pointing to your 127.0.0.1:<port> and a corresponding location routing block.
 * Register the Role:
   Append your new role to the application deployment section within the master orchestration file, ansible/playbooks/playbook.yml.
4. Modifying the Firewall
All ingress traffic is blocked by default via UFW. If you must add a new public-facing service that bypasses Nginx (e.g., a new VPN protocol or game server):
 * Do not write custom shell commands for iptables or ufw inside your new role.
 * Open ansible/roles/firewall/defaults/main.yml.
 * Append your new port and protocol to the existing firewall_allowed_ports dictionary list.
5. Pre-Deployment Validation
Before committing changes or deploying to the permanent host, validate your code:
# Verify playbook syntax and YAML formatting
ansible-playbook -i ansible/inventory/production.ini ansible/playbooks/playbook.yml --syntax-check

# Perform a dry-run execution to review pending state changes safely
ansible-playbook -i ansible/inventory/production.ini ansible/playbooks/playbook.yml --check --diff

## 5. CI/CD Secret Management (GitHub Actions)

To automate deployments via GitHub Actions, your pipeline requires access to your AWS credentials and server SSH key. 

**Prerequisite Expectation:** You should already have your standard AWS variables (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) exported in your current shell environment, as this is required to run Terraform locally.

Use the GitHub CLI (`gh`) to strictly push your existing local environment state up to your repository secrets:

```bash
# Push existing AWS credentials to GitHub secrets
echo "$AWS_ACCESS_KEY_ID" | gh secret set AWS_ACCESS_KEY_ID
echo "$AWS_SECRET_ACCESS_KEY" | gh secret set AWS_SECRET_ACCESS_KEY

# Push SSH private key directly from the local file (preserves multiline formatting)
gh secret set SSH_PRIVATE_KEY < ~/.ssh/id_ed25519
```
