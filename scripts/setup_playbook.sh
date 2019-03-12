ansible-playbook -i inventory/mycluster/hosts.ini cluster.yml -b -v --become-user=ubuntu --private-key=~/.ssh/id_rsa $*
