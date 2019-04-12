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
  source my_firewall.sh $*
}
inventory='inventory/mycluster'
defaults='-b --private-key=~/.ssh/id_rsa --ask-become-pass'
options=""
usage="Usage: $0 [-i,--inventory <inventory/path/to/hosts.ini>] <yaml> [ansible-playbook options]"
usage2="Usage: $0 --crio-setup|--firewall-setup <user>@<master-node-ip> status|enable|disable|..."
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
logger -s "Please, check the ubuntu firewall status..." && ansible-playbook -i ${inventory}/hosts.ini $defaults $options && echo "Next call must be ${inventory}/artifacts/kubectl.sh :
${usage2}"
