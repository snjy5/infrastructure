# Infrastructure Operations Guide

This guide provides the standard operating procedures for deploying and extending the infrastructure. Follow these instructions precisely.

---

## 1. Full System Deployment

Execute these steps in order to provision and configure the entire environment from scratch.

**Step 1: Install Ansible Dependencies**
```bash
ansible-galaxy install -r ansible/requirements.yml
```

**Step 2: Provision Hardware (Terraform)**
```bash
cd terraform/
./tf.sh apply
```
After completion, copy the `public_ip` value from the Terraform output and update the `ansible_host` variable in `ansible/inventory/production.ini`.

**Step 3: Configure Server & Deploy Services (Ansible)**
```bash
ansible-playbook -i ansible/inventory/production.ini ansible/playbooks/playbook.yml
```

---

## 2. Adding a New Service

Follow this exact workflow to integrate a new application. The preferred method is to use a pre-existing, well-maintained community role.

#### **Step 1: Add the Ansible Role**

**Option A: Use a Community Role (Preferred)**

1.  Add the role to `ansible/requirements.yml`.

    ```yaml
    # ansible/requirements.yml
    - src: geerlingguy.redis
    ```

2.  Install it.
    ```bash
    ansible-galaxy install -r ansible/requirements.yml
    ```

**Option B: Create a New Custom Role**

Only do this if a suitable community role does not exist.

1.  Create the role structure.
    ```bash
    ansible-galaxy role init ansible/roles/newapp
    ```

2.  Write your tasks in `ansible/roles/newapp/tasks/main.yml`. Use the `community.docker.docker_compose_v2` module for containerized services.

    ```yaml
    # ansible/roles/newapp/tasks/main.yml
    - name: Ensure newapp directory exists
      ansible.builtin.file:
        path: /opt/newapp
        state: directory
        mode: '0755'

    - name: Deploy newapp container
      community.docker.docker_compose_v2:
        project_src: /opt/newapp
        definition:
          services:
            newapp:
              image: newapp:latest
              restart: unless-stopped
              ports:
                - "127.0.0.1:8080:80" # MUST bind to 127.0.0.1
              volumes:
                - /opt/newapp/data:/data
    ```

#### **Step 2: Enable and Configure the Role in the Master Playbook**

Add the new role to the end of `ansible/playbooks/playbook.yml`. For community roles, define all configuration variables directly under the role definition to ensure they are properly scoped.

```yaml
# ansible/playbooks/playbook.yml
...
  roles:
    - role: common
    - role: security
    - role: firewall
    - role: docker
    - role: nginx
    - role: gitea
    - role: wireguard

    # --- ADD NEW ROLES BELOW THIS LINE ---

    - role: geerlingguy.redis
      vars:
        redis_bind_interface: 127.0.0.1 # Enforce local binding

    - role: newapp
```

#### **Step 3: Expose the Service via Nginx Reverse Proxy**

Do not open the application's port in the firewall. All web traffic is routed through Nginx.

 Edit the master playbook `ansible/playbooks/playbook.yml` and add a new item to the `nginx_vhosts` list within the `geerlingguy.nginx` role definition.

```yaml
 # ansible/playbooks/playbook.yml
 # ...
     - role: geerlingguy.nginx
       vars:
         nginx_remove_default_vhost: true
         nginx_vhosts:
           # ... existing service blocks ...

           # --- Add your new service's proxy config here ---
           - listen: "80"
             server_name: "newapp.yourdomain.com"
             proxy_pass: "http://127.0.0.1:8080"
             proxy_set_headers:
               - "Host $host"
               - "X-Real-IP $remote_addr"
               - "X-Forwarded-For $proxy_add_x_forwarded_for"
               - "X-Forwarded-Proto $scheme"
 # ...
```

---

## 3. Core Development Standards

These rules are mandatory and non-negotiable.

1.  **No Public Container Ports**: Backend application ports must **never** be exposed directly to the internet. Containers must bind strictly to `127.0.0.1` and be routed through the Nginx reverse proxy.
2.  **Centralized Firewall Management**: Do not write custom `iptables` or `ufw` commands in your roles. To open a port for a non-HTTP service (e.g., a game server), append it to the `firewall_allowed_ports` list in `ansible/roles/firewall/defaults/main.yml`.
3.  **Use Handlers for Service Restarts**: Never use the `service` module to restart services directly in `tasks/main.yml`. You **must** use `notify: <Handler Name>` and define the restart logic in the role's `handlers/main.yml`.
4.  **No Hardcoded Variables**: Never hardcode IPs, domains, or passwords in tasks or templates. Define them in `defaults/main.yml` and override them via inventory variables or an encrypted Ansible Vault.
5.  **Strict Idempotency**: Every Ansible run must be safely repeatable. A second run must result in `changed=0` for all tasks. Use modules that manage state or employ `creates`, `removes`, or `changed_when` directives for all shell commands.

---

## 4. CI/CD Secret Management

Automated deployments via GitHub Actions require your AWS and SSH credentials. Push your local environment state to the repository secrets using the GitHub CLI.

```bash
# Push AWS credentials from your local environment
echo "$AWS_ACCESS_KEY_ID" | gh secret set AWS_ACCESS_KEY_ID
echo "$AWS_SECRET_ACCESS_KEY" | gh secret set AWS_SECRET_ACCESS_KEY

# Push the SSH private key from its file
gh secret set SSH_PRIVATE_KEY < ~/.ssh/id_ed25519
```
