#!/usr/bin/env bash
export TOPDIR=$(cd `dirname ${BASH_SOURCE[0]}`/.. && pwd)/
function linux () {
  ssh "${SSH_ARGS[@]}" "$@" "cat /etc/os-release | grep -m1 ID | cut -d= -f2"
}
function linux_family () {
  ssh "${SSH_ARGS[@]}" "$@" "cat /etc/os-release | grep ID_LIKE | cut -d= -f2"
}
function linux_release () {
  ssh "${SSH_ARGS[@]}" "$@" "lsb_release -cs"
}
function set_yml_vars() {
  [ "$#" -lt 3 ] && echo -e "Usage: $0 <path/to/thevars.yml> <var_name> <value>..."
  [ ! -f $1 ] && logger -st $0 "File $1 not found" && exit 1
  file="$1"; k="$2";
  python3 ${TOPDIR}library/yaml-tool.py $*
}
function setup_docker() {
  logger -st kubespray "Docker containerd in Kubespray"
  set_yml_vars $1/all/all.yml "download_container" "true"
  set_yml_vars $1/k8s-cluster/k8s-cluster.yml "etcd_deployment_type" "docker" \
"kubelet_deployment_type" "host" "container_manager" "docker"
  shift
  logger -st ssh "ssh session with \"${SSH_ARGS[*]}\" \"$*\""
  logger -st docker "allow https repository"
  logger -st docker "add docker repository"
# add docker repo - temp fix for ubuntu 19.10 while docker is not available for it
  linux "$@" > linux-name
  linux_release "$@" > lsb-release
  [[ $(linux_family "$@") == 'debian' ]] && ssh "${SSH_ARGS[@]}" "$@" sudo apt-get install \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg-agent \
      software-properties-common -y &
  if [[ $(cat linux-name)  == 'ubuntu' ]]; then
    ssh "${SSH_ARGS[@]}" "$@" "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| sudo apt-key add -"
    ssh "${SSH_ARGS[@]}" "$@" "sudo add-apt-repository \
'deb https://download.docker.com/linux/ubuntu $(cat lsb-release) stable'" &
  elif [[ $(linux_family "$@") == 'debian' ]]; then
    ssh "${SSH_ARGS[@]}" "$@" "sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
| sudo apt-key add -"
    ssh "${SSH_ARGS[@]}" "$@" "sudo add-apt-repository \
'deb https://download.docker.com/linux/$(cat linux-name)  \
$(cat lsb-release) \
stable'" &
  fi
  if [[ $(linux_family "$@") == 'debian' ]]; then
    logger -st docker "remove old docker-ce"
    ssh "${SSH_ARGS[@]}" "$@" sudo apt-get remove docker docker-engine docker.io containerd runc -y
    logger -st docker "get docker-ce"
    ssh "${SSH_ARGS[@]}" "$@" sudo apt-get update
    ssh "${SSH_ARGS[@]}" "$@" sudo apt-get install docker-ce -y
    ssh "${SSH_ARGS[@]}" "$@" sudo apt-get install docker-ce-cli containerd.io -y
  elif [[ $(linux_family "$@") == 'centos' ]]; then
    ssh "${SSH_ARGS[@]}" "$@" "sudo yum install -y yum-utils \
device-mapper-persistent-data \
lvm2" &
    ssh "${SSH_ARGS[@]}" "$@" "sudo yum-config-manager \
--add-repo \
https://download.docker.com/linux/centos/docker-ce.repo" &
  logger -st docker "get docker-ce"
    ssh "${SSH_ARGS[@]}" "$@" sudo yum install -y docker-ce
    ssh "${SSH_ARGS[@]}" "$@" sudo yum install -y docker-ce-cli containerd.io
  fi
  DKR_ARCH=$(ssh "${SSH_ARGS[@]}" "$@" arch)
  ARCHS=("aarch64" "arm64v8")
  for a in "${ARCHS[@]}"; do if [[ $DKR_ARCH = "$a" ]]; then
    printf "Hotfix: Docker-ce for ARM64 (%s)" https://gist.githubusercontent.com/tstellanova/\
714c64fe476eef467982c93976c955be/raw/d21027b878e3c128d13ed46ec9f8a1db72efa52d/install-docker-arm64.sh
    ssh "${SSH_ARGS[@]}" "$@" sudo tee /etc/docker/daemon.json <<EOF
{
  "insecure-registries": ["rock64-01.local:5000","10.0.1.5:5000"]
}
EOF
  fi; done
  logger -st docker "If you would like to use docker as non-root user thatsme : \
ssh \"${SSH_ARGS[*]}\" \"$*\" sudo usermod -aG docker thatsme"
}
function setup_firewall() {
  usage="Usage: $0 [-n|--node] status|enable|disable|.. "
  host=''
  iptables_reset='sudo iptables -t nat -F;
  sudo iptables -t mangle -F;
  sudo iptables -F;
  sudo iptables -X;'
  ufw_rules='sudo ufw allow OpenSSH;
sudo ufw allow 443/tcp;
sudo ufw allow 123/udp;
sudo ufw allow 53/udp;
sudo ufw allow 8443/tcp;
# loadbalancer_apiserver_port
sudo ufw allow 6443/tcp;
# weave
sudo ufw allow 6782:6784/tcp;
sudo ufw allow 2379:2380/tcp;
sudo ufw allow 10250:10255/tcp;
# ssh
sudo ufw allow 65535/tcp;
# loadbalancer_apiserver_healthcheck_port
sudo ufw allow 8081/tcp;
# nodelocaldns_health_port
sudo ufw allow 9254/tcp;'
  ufw_log='sudo ufw logging on;
  sudo ufw logging medium;'
  while [ "$#" -gt 0 ]; do case $1 in
    -n*|--node)
      ufw_rules='sudo ufw allow OpenSSH;
sudo ufw allow 30000:32767/tcp;
sudo ufw allow 10250:10255/tcp;
# weave
sudo ufw allow 6782:6784/tcp;
# ssh
sudo ufw allow 65535/tcp;
# nodelocaldns_health_port
sudo ufw allow 9254/tcp;'
      printf "Applying node rules..."
      ;;
    enable)
      shift
      ssh "${SSH_ARGS[@]}" "$@" sudo ufw disable
      ssh "${SSH_ARGS[@]}" "$@" "${iptables_reset}${ufw_log}${ufw_rules}"
      ssh "${SSH_ARGS[@]}" "$@" sudo ufw --force enable
      break;;
    disable)
      shift
      ssh "${SSH_ARGS[@]}" "$@" sudo ufw disable
      ssh "${SSH_ARGS[@]}" "$@" "${iptables_reset}${ufw_rules}"
      break;;
    *)
      cmd=$1
      shift
      ssh "${SSH_ARGS[@]}" "$@" sudo ufw "${cmd}"
      ssh "${SSH_ARGS[@]}" "$@" "${ufw_log}"
      break;;
  esac; shift; done
}
defaults=(-i ${HOME}/.ssh/id_rsa)
usage=(
"Usage: $0 -k, --kube--hosts <inventory/hosts.yaml> <etcd|kube-master|kube-node|..>]"
"     [--docker-setup <inventory/path/to/group_vars> <ssh-args>|-F ssh-bastion.conf"
"     -k, --kube--hosts <inventory/hosts.yaml> <etcd|kube-master|kube-node|..>]"
"     [--firewall-setup [-n|--node] status|enable|disable|.. <ssh-args>|-F ssh-bastion.conf ]"
"     -p,--proxy <securized_host> <bastion_host> <user>"
"     -m,--memory-mb <minimal_node_memory_mb> <minimal_master_memory_mb>"
"")
[ "$#" -lt 1 ] && printf "%s\n" "${usage[@]}" && exit 0
declare -a SSH_ARGS=()
while [ "$#" -gt 0 ]; do case $1 in
  -k|--kube-hosts)
    shift
    # setup user@ip as hosts
    hosts=($(python3 ${TOPDIR}library/yaml-tool.py --kube-hosts="$1" "$2" ansible_ssh_host))
    users=($(python3 ${TOPDIR}library/yaml-tool.py --kube-hosts="$1" "$2" ansible_user))
    export KUBE_HOSTS="${users[0]}@${hosts[0]}"
    printf "host %s: %s\n" $2 $KUBE_HOSTS
    shift
    ;;
  --docker-setup)
    shift
    [ "$#" -lt 1 ] && echo -e "${usage[1]}" && exit 0
    setup_docker "$@" "${KUBE_HOSTS}"
    exit 0;;
  --firewall-setup)
    shift
    [ "$#" -lt 1 ] && echo -e "${usage[3]}" && exit 0
    setup_firewall "$@" "${KUBE_HOSTS}"
    exit 0;;
  -p|--proxy)
    shift
    [ "$#" -lt 3 ] && echo -e "${usage[5]}" && exit 0
    declare -a SSH_ARGS=(-o ProxyCommand="bash -c 'ssh -W $1:22 -qA ${defaults[@]} $3@$2'" "${defaults[@]}" $3@$1)
    shift; shift
    logger -st ssh "Options \"${SSH_ARGS[*]}\""
    [[ "$#" == 1 ]] && ssh "${SSH_ARGS[@]}" && exit 0;;
  -m|--memory-mb)
    shift
    [ "$#" -lt 2 ] && echo -e "${usage[6]}" && exit 0
    set_yml_vars roles/kubernetes/preinstall/defaults/main.yml "minimal_node_memory_mb" $1
    set_yml_vars roles/kubernetes/preinstall/defaults/main.yml "minimal_master_memory_mb" $2
    sudo sed -i -E /memory/s/"'([0-9]+)'"/\\1/g roles/kubernetes/preinstall/defaults/main.yml
    ;;
  -h|--help)
    printf "%s\n" "${usage[@]}"
    exit 0;;
  *) printf "Unknown %s as argument" $1;;
esac; shift; done
