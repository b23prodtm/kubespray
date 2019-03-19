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
      ssh $1 'sudo apt install firewalld;
      firewall-cmd --permanent --add-port=30000-32767/tcp;
      firewall-cmd --permanent --add-port=10250/tcp;
      firewall-cmd --permanent --add-port=10255/tcp;
      firewall-cmd --permanent --add-port=6783/tcp;
      firewall-cmd —reload' || echo "Usage: $0 --firewall-setup -n user@host"
      break;;
    *)
      ssh $1 'sudo apt install firewalld;
      firewall-cmd --permanent --add-port=6443/tcp;
      firewall-cmd --permanent --add-port=2379/tcp;
      firewall-cmd --permanent --add-port=2380/tcp;
      firewall-cmd --permanent --add-port=10250/tcp;
      firewall-cmd --permanent --add-port=10251/tcp;
      firewall-cmd --permanent --add-port=10252/tcp;
      firewall-cmd --permanent --add-port=10255/tcp;
      firewall-cmd —reload;' || echo "Usage: $0 --firewall-setup user@host"
      break;;
  esac; shift; done
}
while [ "$#" -gt 0 ]; do case $1 in
  --crio-setup)
    shift
    setup_crio $1;;
  --firewall-setup)
    shift
    setup_firewall $1;;
  *)
    ansible-playbook -i inventory/mycluster/hosts.ini cluster.yml -b -v --private-key=~/.ssh/id_rsa $*
    break;;
esac; shift; done
