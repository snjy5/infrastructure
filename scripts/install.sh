apt install ansible ssh -y
systemctl start ssh
ssh-keygen

nms_dir="ansible/roles/nginx"
nms_req="$nms_dir/requirements.yml"
nms_install="$nms_dir/nms-install.yml"
nms_pb="$nms_dir/nms-playbook.yml"
inventory="ansible/inventory/inventory.yml"
pb="ansible/playbooks/playbook.yml"

ansible-galaxy install -fr $nms_req
ansible-playbook -i $inventory $nms_install
ansible-playbook -i $inventory $nms_pb

ansible-playbook -i $inventory $pb

timeout 30 ansible all -i $inventory -m ping