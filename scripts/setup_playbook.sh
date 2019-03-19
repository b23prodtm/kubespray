function setup_crio() {
   ssh $1 '
   sudo add-apt-repository ppa:projectatomic/ppa;
   sudo apt-get update;
   sudo apt install cri-o-1.13;
   sudo chmod 0755 /etc/crio; sudo chown ubuntu:ubuntu -R /etc/crio;
   sudo chmod 0755 /etc/containers; sudo chown ubuntu:ubuntu -R /etc/containers;
   ' || echo "Usage: $0 user@host"
}
while [ "$#" -gt 0 ]; do case $1 in
  --crio-setup)
    shift
    setup_crio $1;;
  *)
    ansible-playbook -i inventory/mycluster/hosts.ini cluster.yml -b -v --private-key=~/.ssh/id_rsa $*
    break;;
esac; shift; done
