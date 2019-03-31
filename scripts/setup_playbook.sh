function setup_crio() {
   ssh $1 '
   sudo add-apt-repository ppa:projectatomic/ppa;
   sudo apt-get update;
   sudo apt install cri-o-1.13;
   sudo chmod 0755 /etc/crio; sudo chown ubuntu:ubuntu -R /etc/crio;
   sudo chmod 0755 /etc/containers; sudo chown ubuntu:ubuntu -R /etc/containers;
   ' || echo "Usage: $0 --crio-setup user@host"
}
function setup_firewall() {
  while [ "$#" -gt 0 ]; do case $1 in
    -n*)
      shift
      ssh $* 'sudo apt install firewalld;
      sudo firewall-cmd --permanent --add-port=30000-32767/tcp;
      sudo firewall-cmd --permanent --add-port=10250/tcp;
      sudo firewall-cmd --permanent --add-port=10255/tcp;
      sudo firewall-cmd --permanent --add-port=6783/tcp;
      sudo firewall-cmd --reload' $* || echo "Usage: $0 --firewall-setup -n user@host"
      break;;
    *)
      ssh $* 'sudo apt install firewalld;
      sudo firewall-cmd --permanent --add-port=6443/tcp;
      sudo firewall-cmd --permanent --add-port=2379/tcp;
      sudo firewall-cmd --permanent --add-port=2380/tcp;
      sudo firewall-cmd --permanent --add-port=10250/tcp;
      sudo firewall-cmd --permanent --add-port=10251/tcp;
      sudo firewall-cmd --permanent --add-port=10252/tcp;
      sudo firewall-cmd --permanent --add-port=10255/tcp;
      sudo firewall-cmd --reload' || echo "Usage: $0 --firewall-setup user@host"
      break;;
  esac; shift; done
}
inventory='inventory/mycluster/hosts.ini'
defaults='-b -v --private-key=~/.ssh/id_rsa'
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
    setup_crio $* -i ~/.ssh/id_rsa
    exit 0;;
  --firewall-setup)
    shift
    setup_firewall $* -i ~/.ssh/id_rsa
    exit 0;;
  -i*|--inventory)
    shift
    inventory=$1;;
  -h*|--help)
    echo $usage
    echo $usage2;;
  -b*|-v*|--private-key*)
    options="${options} $1"
    defaults="";;
  *) options="${options} $1";;
esac; shift; done
ansible-playbook -i $inventory $defaults $options && echo "Next call must be a firewall-cmd :
${usage2}"
