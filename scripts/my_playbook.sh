#!/usr/bin/env bash
export work_dir=$(echo $0 | awk -F'/' '{ print $1 }')'/'
function set_yml_vars() {
   [ "$#" -lt 3 ] && echo -e "Usage: $0 <path/to/thevars.yml> <var_name> <value>..."
   [ ! -f $1 ] && logger -st $0 "File $1 not found" && exit 1
   file="$1"; k="$2";
   python3 ${work_dir}../library/yaml-tool.py $*
}
function setup_crio() {
   logger -st kubespray "CRI-O's plugin in Kubespray"
   set_yml_vars $2/all/all.yml "download_container" "false" "skip_downloads" "false"
   set_yml_vars $2/k8s-cluster/k8s-cluster.yml "etcd_deployment_type" "host" "kubelet_deployment_type" "host" "container_manager" "crio"
   ssh $1 '
   sudo add-apt-repository ppa:alexlarsson/flatpak;
   sudo add-apt-repository ppa:projectatomic/ppa;
   sudo apt-get update;
   sudo apt install libostree-dev cri-o-1.13 cri-o-runc;
   sudo chmod 0755 /etc/crio; sudo chown ubuntu:ubuntu -R /etc/crio;
   sudo chmod 0755 /etc/containers; sudo chown ubuntu:ubuntu -R /etc/containers;
   ' || echo "Usage: $0 --crio-setup user@host inventory/path/to/group_vars"
}
function setup_docker() {
  logger -st kubespray "Docker containerd in Kubespray"
  set_yml_vars $2/all/all.yml "download_container" "true"
  set_yml_vars $2/k8s-cluster/k8s-cluster.yml "etcd_deployment_type" "docker" "kubelet_deployment_type" "host" "container_manager" "docker"
  logger -st ssh "ssh session with $1"
  ssh $1 logger -st docker "allow https repository"
  ssh $1 sudo apt-get install \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg-agent \
      software-properties-common -y &
  ssh $1 logger -st docker "add docker repository packages"
  ssh $1 sudo add-apt-repository \
'deb https://download.docker.com/linux/ubuntu bionic stable' &
  ssh $1 logger -st docker "add docker repository key"
  ssh $1 sudo "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -"
  ssh $1 logger -st docker "remove old docker-ce"
  ssh $1 sudo apt-get remove docker docker-engine docker.io containerd runc -y 
  ssh $1 logger -st docker "get docker-ce for ubuntu bionic"
  ssh $1 sudo apt-get update && sudo apt-get install docker-ce -y
  ssh $1 sudo apt-get install docker-ce-cli containerd.io -y
}
function setup_firewall() {
  source my_firewall.sh $*
}
inventory='inventory/mycluster/inventory.ini'
defaults='-b --private-key=~/.ssh/id_rsa'
options=""
usage="Usage: $0 [-i,--inventory <inventory/path/to/inventory.ini>] <yaml> [ansible-playbook options]"
usage2="Usage: $0 --crio-setup <user>@<master-node-ip> <inventory/path/to/group_vars>"
usage3="Usage: $0 --firewall-setup <user>@<master-node-ip> status|enable|disable|..."
[ "$#" -lt 1 ] && echo "
${usage}
${usage2}
${usage3}
" && exit 0
while [ "$#" -gt 0 ]; do case $1 in
  --crio-setup)
    shift
    setup_crio $@ -i ~/.ssh/id_rsa
    exit 0;;
  --docker-setup)
    shift
    setup_docker $@ -i ~/.ssh/id_rsa
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
logger -s "Disable the cluster firewall if you can..."
logger -s "If a TASK failed on timeouts, reboot the kubernetes cluster before to retry..."
logger -s "Known TASKs that take more time : [Start of Calico kube controllers], [Kubernetes Apps | Start Resources]..."
logger -s "It's going to take about half an hour per host to complete the cluster boot process..."
logger -s "Please don't shutdown anything until it finishes..." && ansible-playbook -i ${inventory} $defaults $options && echo "Next call must be scripts/start_dashboard.sh --timeout=60"
