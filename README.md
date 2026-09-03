# Description
This is an Ansible + Terraform project with the CI/CD pipeline orchestrated in Ansible.

# Infrastructure Operations Guide & Handbook

This guide provides the standard operating procedures for deploying and extending the infrastructure. Follow these instructions precisely to maintain a secure, idempotent, and automated environment.

---

## 1. Full System Deployment

This infrastructure is designed for fully automated deployment via CI/CD. Manual provisioning is discouraged.

**Automated Deployment (Recommended)**
Push your code to the `master` branch. The GitHub Actions workflow will automatically:
1. Provision the AWS infrastructure via Terraform and configure SSH credentials (`ansible/playbooks/orchestrate.yml`).
2. Validate the configuration by deploying against the CI runner itself as a smoke test.
3. Deploy the validated configuration to the production server using the auto-generated inventory.

**Manual Deployment (For Local Testing)**
If you must run the deployment manually from your local machine, replicate the pipeline steps in order:

```bash
# Step 1: Provision infrastructure and SSH setup
ansible-playbook \
  -i ansible/inventory/local.ini \
  --vault-password-file secrets/vault \
  ansible/playbooks/orchestrate.yml

# Step 2: Validate configuration locally
ansible-playbook \
  -i ansible/inventory/local.ini \
  --vault-password-file secrets/vault \
  ansible/playbooks/playbook.yml

# Step 3: Deploy to production
ansible-playbook \
  -i ansible/inventory/production.ini \
  --vault-password-file secrets/vault \
  ansible/playbooks/playbook.yml
```

*Note: Terraform automatically generates `ansible/inventory/production.ini` during the orchestration stage. Do not edit the inventory file manually.*

---

## 2. Adding a New Service

How you add a service depends entirely on whether it is an **Application** or a **System Configuration**.

### A. Adding an Application (e.g., Web App, Database, Gitea)
Applications are strictly managed by Docker Compose. **Do not use Ansible to deploy applications.**

1. **Define the Container:** Open `docker-compose.yml` in the root directory and add your new service.
2. **Enforce Local Binding:** Ensure the container's port binds *only* to localhost so it is not exposed directly to the internet.
```yaml
   ports:
     - "127.0.0.1:8080:80" # Correct
     # - "8080:80"         # WRONG - Exposes to the public internet
```
3. **Configure the Reverse Proxy:** Open `ansible/inventory/group_vars/webservers.yml` and add your service to the `services` list. Ansible will automatically generate the Nginx reverse proxy configuration for you on the next run.
```yaml
   # ansible/inventory/group_vars/webservers.yml
   services:
     - name: gitea
       port: 3000
     - name: newapp      # <--- Add your new app here
       port: 8080
```

### B. Adding a System Configuration (e.g., VPN, Monitoring, OS Tweaks)
System configurations are managed by Ansible.

**Rule: Always use Community Roles.**
We do not maintain custom local roles in this repository to keep the codebase clean and reusable.

1. **Search First:** Find a well-maintained role on [Ansible Galaxy](https://galaxy.ansible.com/) (e.g., `geerlingguy.security`).
2. **Add to Requirements:** Add the role to `ansible/requirements.yml` and pin the version.
```yaml
   roles:
     - name: geerlingguy.redis
       version: "1.5.0"
```
3. **Enable the Role:** Add the role to the `roles:` list in `ansible/playbooks/playbook.yml`.
4. **Configure the Role:** Pass role variables via `ansible/inventory/group_vars/webservers.yml`.
5. **Publish if Missing (Custom Roles):** If a role does not exist for your specific need, **do not write it locally**. Instead:
   * Create a new public GitHub repository (e.g., `ansible-role-custom-sysctl`).
   * Initialize it: `ansible-galaxy role init <username>.<role_name>`
   * Write your tasks, commit, and push to GitHub.
   * Import the repository into Ansible Galaxy.
   * Pull it into this project via `requirements.yml` just like any other community role.

---

## 3. Core Development Standards

These rules are mandatory and non-negotiable.

1.  **Strict Separation of Concerns (Ansible vs. Docker):**
    *   **Ansible** is strictly for host-level configuration (Firewall, OS updates, user management, installing Docker/Nginx, and low-level network services like WireGuard).
    *   **Docker Compose** is strictly for application services (Gitea, Databases, Web Apps).
2.  **No Public Container Ports**: Backend application ports must **never** be exposed directly to the internet. Containers must bind strictly to `127.0.0.1` and be routed through the Nginx reverse proxy.
3.  **Centralized Firewall Management**: Do not write custom `iptables` or `ufw` commands in your roles. To open a port for a non-HTTP service (e.g., a game server), append it to `firewall_allowed_tcp_ports` or `firewall_allowed_udp_ports` in `ansible/inventory/group_vars/webservers.yml`.
4.  **Use Handlers for Service Restarts**: Never use the `service` module to restart services directly in `tasks/main.yml`. You **must** use `notify: <Handler Name>` and define the restart logic in the role's `handlers/main.yml`.
5.  **No Hardcoded Variables**: Never hardcode IPs, domains, or passwords in tasks or templates. Define them in `defaults/main.yml` or pass them via CI/CD environment variables.
6.  **Strict Idempotency**: Every Ansible run must be safely repeatable. A second run must result in `changed=0` for all tasks. Use modules that manage state or employ `creates`, `removes`, or `changed_when` directives for all shell commands.
7.  **Centralized Configuration**: All role variables and application settings belong in `ansible/inventory/group_vars/webservers.yml`. Playbook-level `vars:` must only contain computed intermediate values specific to that play.

---

## 4. CI/CD Secret Management

Automated deployments via GitHub Actions require AWS credentials and an Ansible Vault password. All other secrets (SSH keys, database passwords, etc.) are stored inside the encrypted Vault file, not as raw GitHub secrets.

### Creating the Vault Password File

Generate a strong vault password and store it in `secrets/vault`. This file must never be committed.

```bash
mkdir -p secrets
echo "YOUR_STRONG_VAULT_PASSWORD" > secrets/vault
```

### Managing the Encrypted Vault

The encrypted vault lives at `ansible/inventory/group_vars/all/vault.yml`. It is committed to the repository in encrypted form.

**Create a new vault from scratch:**

```bash
ansible-vault create ansible/inventory/group_vars/all/vault.yml --vault-password-file secrets/vault
```

This opens your default editor. Add your secrets in plain YAML:

```yaml
vault_aws_access_key_id: "AKIA..."
vault_aws_secret_access_key: "..."
vault_ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
vault_gitea_db_password: "..."
vault_mysql_root_password: "..."
```

Save and close. The file is encrypted automatically on disk.

**Edit an existing vault:**

```bash
ansible-vault edit ansible/inventory/group_vars/all/vault.yml --vault-password-file secrets/vault
```

**View vault contents without editing:**

```bash
ansible-vault view ansible/inventory/group_vars/all/vault.yml --vault-password-file secrets/vault
```

**Encrypt a single string inline** (useful for adding one secret without opening the full vault):

```bash
ansible-vault encrypt_string --vault-password-file secrets/vault 'my_secret_value' --name 'vault_my_variable'
```

Copy the output and paste it directly into `vault.yml`.

### Git Ignore

The `secrets/` directory must be ignored. **Never commit anything inside it.**

```bash
echo "secrets/" >> .gitignore
```

Verify:

```bash
git status  # secrets/ should NOT appear
```

### Pushing Secrets to GitHub Actions

Only three secrets are needed in GitHub Actions. The encrypted Vault file (`vault.yml`) is committed to the repo and decrypted at runtime using `VAULT_PASSWORD`.

```bash
# Push AWS credentials
echo "$AWS_ACCESS_KEY_ID" | gh secret set AWS_ACCESS_KEY_ID
echo "$AWS_SECRET_ACCESS_KEY" | gh secret set AWS_SECRET_ACCESS_KEY

# Push the vault password (unlocks all other secrets at deploy time)
cat secrets/vault | gh secret set VAULT_PASSWORD
```

> ⚠️ **Note:** It is highly recommended to generate a dedicated SSH deploy key (e.g., `id_ed25519_deploy`) rather than using your personal SSH key. Store the private key content inside `vault.yml` as `vault_ssh_private_key`, not as a separate GitHub secret.
