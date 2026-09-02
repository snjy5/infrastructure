# Description
This is a ansible+terraform project with the CI/CD pipeline themselves in ansible.

# Infrastructure Operations Guide & Handbook

This guide provides the standard operating procedures for deploying and extending the infrastructure. Follow these instructions precisely to maintain a secure, idempotent, and automated environment.

---

## 1. Full System Deployment

This infrastructure is designed for fully automated deployment via CI/CD. Manual provisioning is discouraged.

**Automated Deployment (Recommended)**
Push your code to the `master` branch. The GitHub Actions workflow will automatically:
1. Validate the Ansible syntax locally.
2. Provision the AWS infrastructure via Terraform.
3. Auto-generate the Ansible inventory file.
4. Configure the host OS and install dependencies via Ansible.

**Manual Deployment (For Local Testing)**
If you must run the deployment manually from your local machine, execute the wrapper script:
```bash
./ci-deploy.sh
```
*Note: Terraform will automatically fetch the new server IP and generate `ansible/inventory/production.ini` for you. Do not edit the inventory file manually.*

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
3. **Configure the Reverse Proxy:** Open `ansible/playbooks/playbook.yml` and add your service to the `services` list. Ansible will automatically generate the Nginx reverse proxy configuration for you on the next run.
   ```yaml
   # ansible/playbooks/playbook.yml
   vars:
     main_domain: "yourdomain.com"
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
4. **Publish if Missing (Custom Roles):** If a role does not exist for your specific need, **do not write it locally**. Instead:
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
3.  **Centralized Firewall Management**: Do not write custom `iptables` or `ufw` commands in your roles. To open a port for a non-HTTP service (e.g., a game server), append it to the firewall tasks in your base playbook.
4.  **Use Handlers for Service Restarts**: Never use the `service` module to restart services directly in `tasks/main.yml`. You **must** use `notify: <Handler Name>` and define the restart logic in the role's `handlers/main.yml`.
5.  **No Hardcoded Variables**: Never hardcode IPs, domains, or passwords in tasks or templates. Define them in `defaults/main.yml` or pass them via CI/CD environment variables.
6.  **Strict Idempotency**: Every Ansible run must be safely repeatable. A second run must result in `changed=0` for all tasks. Use modules that manage state or employ `creates`, `removes`, or `changed_when` directives for all shell commands.

---

## 4. CI/CD Secret Management

Automated deployments via GitHub Actions require your AWS and SSH credentials. Push your local environment state to the repository secrets using the GitHub CLI.

*Note: It is highly recommended to generate a dedicated SSH deploy key (e.g., `id_ed25519_deploy`) rather than using your personal SSH key.*

```bash
# Push AWS credentials from your local environment
echo "$AWS_ACCESS_KEY_ID" | gh secret set AWS_ACCESS_KEY_ID
echo "$AWS_SECRET_ACCESS_KEY" | gh secret set AWS_SECRET_ACCESS_KEY

# Push the dedicated SSH private key
gh secret set SSH_PRIVATE_KEY < ~/.ssh/id_ed25519_deploy
```
