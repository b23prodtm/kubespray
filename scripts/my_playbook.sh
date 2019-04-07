function setup_crio() {
   ssh $1 '
   sudo add-apt-repository ppa:alexlarsson/flatpak;
   sudo add-apt-repository ppa:projectatomic/ppa;
   sudo apt-get update;
   sudo apt install libostree-dev cri-o-1.13 cri-o-runc;
   sudo chmod 0755 /etc/crio; sudo chown ubuntu:ubuntu -R /etc/crio;
   sudo chmod 0755 /etc/containers; sudo chown ubuntu:ubuntu -R /etc/containers;
   ' || echo "Usage: $0 --crio-setup user@host"
}
function setup_firewall() {
  usage="Usage: $0 --firewall-setup [-n[ode]] user@host status|enable|disable|.."
  while [ "$#" -gt 0 ]; do case $1 in
    -n*) # cluster-node
      shift
      ssh $1 'sudo ufw allow OpenSSH;
      sudo ufw allow 30000:32767/tcp;
      sudo ufw allow 10250/tcp;
      sudo ufw allow 10255/tcp;
      sudo ufw allow 6783/tcp;'
      break;;
    *) # cluster-master
      ssh $1 'sudo ufw allow OpenSSH;
      sudo ufw allow 6443/tcp;
      sudo ufw allow 2379/tcp;
      sudo ufw allow 2380/tcp;
      sudo ufw allow 10250/tcp;
      sudo ufw allow 10251/tcp;
      sudo ufw allow 10252/tcp;
      sudo ufw allow 10255/tcp;'
      break;;
  esac; shift; done
  ssh $1 '
  sudo ufw logging on;
  sudo ufw logging medium;
  sudo ufw '$2 || echo $usage
}
inventory='inventory/mycluster/hosts.ini'
defaults='-b --private-key=~/.ssh/id_rsa --ask-become-pass'
options=""
usage="Usage: $0 [-i,--inventory <inventory/path/to/hosts.ini>] <yaml> [ansible-playbook options]"
usage2="Usage: $0 --crio-setup|--firewall-setup <user>@<master-node-ip>"
[ "$#" -lt 1 ] && echo "
${usage}
${usage2}
" && exit 0
while [ "$#" -gt 0 ]; do case $1 in
  --crio-setup)
    shift
    setup_crio $@ -i ~/.ssh/id_rsa
    exit 0;;
  --firewall-setup)
    shift
    setup_firewall $@ -i ~/.ssh/id_rsa
    exit 0;;
  -i*|--inventory)
    shift
    inventory=$1;;
  -h*|--help)
    echo $usage
    echo $usage2;;
  -b*|--private-key*)
    options="${options} $1"
    defaults="";;
  *) options="${options} $1";;
esac; shift; done
ansible-playbook -i $inventory $defaults $options && echo "Next call must be a firewall-cmd :
${usage2}"
