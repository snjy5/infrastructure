apt install ansible -y
nms_dir="ansible/roles/nginx"
req_file="$nms_dir/requirements.yml"
nms_install_file="$nms_dir/nms-install.yml"
nms_pb_file="$nms_dir/nms-playbook.yml"


ansible-galaxy install -fr $req_file
ansible-playbook -i inventory $nms_install_file
ansible-playbook -i /etc/hosts $nms_pb_file