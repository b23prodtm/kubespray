#!/usr/bin/env bash
export TOPDIR=$(cd `dirname ${BASH_SOURCE[0]}`/.. && pwd)/
usage="\
\n\
Usage: [CONFIG_FILE=inventory/mycluster/inventory.yaml] $0 [node1,alice@IP0 node2,joe@IP1 bob@IP..] \n\
\n\
  Default options creates a new inventory file and updates node1, 2, ... from hosts.yaml file. \n\
  If you cannot reach the hosts by refused connection, check your firewall, and DHCP subnets: \n\
\n\
  Ubuntu firewall: \n\
    sudo ufw allow OpenSSH \n\
\n\
  ISC DHCP Service from bastion host, log in to edit subnets: \n\
    sudo nano /etc/dhcp/dhcpd.conf\n\
\n\
  On target host (securized subnet), configure: \n\
    echo \"SSHD: ALL\" | sudo tee -a /etc/hosts.allow \n\
    cat /etc/hosts.allow && sudo /etc/init.d/ssh restart \n\
\n\
This will permanently allow all SSH connection from everywhere, protected by a login.\n"
# Update Ansible inventory file with inventory builder . Single master cluster is possible.
# How to use 2 nodes with Calico and Route Reflectors, in docs/calico.md.
#
function cfrm_act () {
def_go=$2
y='y'
n='n'
[ "$def_go" == "$y" ] && y='Y'
[ "$def_go" == "$n" ] && n='N'
while true; do case $go in
        [nN]*) break;;
        [yY]*) echo $go; break;;
	*)
		read -p "Confirm $1 [${y}/${n}] ? " go
		[ -z $go ] && go=$def_go;;
esac; done
}
IFS=' ' # Read prompt Field Separator
while [ "$#" -gt 0 ]; do case $1 in
  -h*|--help)
    echo -e $usage
    exit 0;;
  *)
    declare -a IPS=($@)
    break;;
esac; shift; done
while [[ -z $IPS ]]; do
  read -p "Please type in up to 6 local network ip${IFS}john@ip${IFS}elisa@ip...: (CTRL-C to exit) " -a ips
  echo -e "\n"
  if [[ ${#ips[@]} -ge 1 ]]; then
    if [[ $(cfrm_act "you've entered the correct ips addresses ${ips[0]} ${ips[1]} \
${ips[2]} ${ips[3]} ${ips[4]} ${ips[5]}" 'n') ]]; then
      declare -a IPS=(${ips[@]})
    fi
  else
      echo -e "Enter one or more valid IP addresses of the form X.X.X.X : X€[0;255] \n"
  fi
done
BASTION=$(echo "${IPS[0]}" | awk 'BEGIN{FS=","}{if (NF > 1) print $2; else print $1}')
while true; do read -p "If the bastion host's set and keep it, press ENTER. ip${IFS}john@ip${IFS}elisa@ip... \
otherwise N to set none [${BASTION}]: " answer
case answer in
  [Nn]*) BASTION="" break;;
  *)
    [ ! -z $answer ] && BASTION=$answer
    break;;
esac; done
logger -st kubespray "IPS=(${IPS[*]})\n"
export CONFIG_FILE=${CONFIG_FILE:-"${TOPDIR}inventory/mycluster/inventory.yaml"}
INV=$(dirname $CONFIG_FILE)
GVARS=$INV/group_vars
HOSTS=$INV/hosts.yaml
logger -st systemd "Check DNS server values in ${GVARS}"
dns1=""
if [ -f /etc/os-release ]; then #linux_family
  dns1=$(systemd-resolve --status | grep 'DNS Servers:' | awk '/([0-9]*\.){3}/{print $3}' | head -n 1)
  if [ $(cfrm_act "Should I copy kubectl to localhost ?" 'y') ]; then
    python3 library/yaml-tool.py ${GVARS}/k8s-cluster/k8s-cluster.yml kubectl_localhost true
  fi
else # mac_os
  dns1=$(scutil --dns | grep "nameserver\[.\] :" | awk '/([0-9]*\.){3}/{print $3}' | head -n 1)
  if [ $(cfrm_act "Should I download and install kubectl to localhost ?" 'n') ]; then
    brew install kubectl
  fi
fi
if [ $(cfrm_act "Should I copy kube admin.conf to localhost ?" 'y') ]; then
  python3 library/yaml-tool.py ${GVARS}/k8s-cluster/k8s-cluster.yml kubeconfig_localhost true
fi
logger -st kubespray "****** K8s ansible : Generate $INI and $CONFIG_FILE ******"
cat $HOSTS
[ -f $CONFIG_FILE ] && cp -f $CONFIG_FILE $CONFIG_FILE.old
while [ $(cfrm_act "You wish to update the CONFIG_FILE=$CONFIG_FILE with the changes ${IPS[*]} ?" 'y') ]; do
  rm $CONFIG_FILE
  python3 contrib/inventory_builder/inventory.py load $HOSTS
  python3 contrib/inventory_builder/inventory.py ${IPS[*]}
  [ -f $CONFIG_FILE ] && cat $CONFIG_FILE
  [ $(cfrm_act "You wish to use the CONFIG_FILE=$CONFIG_FILE ?" 'y') ] && break || cp -f $CONFIG_FILE.old $CONFIG_FILE
done
cat $GVARS/all/all.yml
[ $(cfrm_act "the options" 'y') ] || exit 0
cat $GVARS/k8s-cluster/k8s-cluster.yml
[ $(cfrm_act "the kubernetes configuration" 'y') ] || exit 0
${TOPDIR}my_playbook.sh cluster.yml --tags=localhost,bastion
# loop over IPS using BASTION connection proxy if necessary
for ip in "${IPS[@]}"; do
  # awk split(',')
  ip=$(echo "${ip}" | awk 'BEGIN{FS=","}{if (NF > 1) print $2; else print $1}')
  ssh_args=(-F ssh-bastion.conf -o ControlMaster=auto -o ControlPersist=30m -o ConnectionAttempts=100 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${HOME}/.ssh/id_rsa)
  logger -st kubespray-$ip "****** K8s ip : ${ip} ******"
  [ $(cfrm_act "to skip ${ip} configuration" 'n') ] && continue
  if [[ (! -z $BASTION ) && (! $BASTION == "${ip}") ]]; then
#    ssh_args=(${ssh_args[@]} -o ProxyCommand="ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W ${ip}:22 -qA ${BASTION} ${ssh_args[@]} ")
    ssh "${ssh_args[@]}" $BASTION ssh-copy-id $ip
  else
    ssh-copy-id $ip
  fi
  linux=$(ssh "${ssh_args[@]}" $ip "cat /etc/os-release | grep -m1 ID | cut -d= -f2")
  linux_family=$(ssh "${ssh_args[@]}" $ip "cat /etc/os-release | grep ID_LIKE | cut -d= -f2")
  ssh "${ssh_args[@]}" $ip logger -st ssh-bastion "login success"
  logger -st kubespray-$ip "configure sshd root access if you login with root@"
  if [ $(cfrm_act "to add ssh root configuration" 'n') ]; then
    ssh "${ssh_args[@]}" $ip "sudo sed -i /'PermitRootLogin'/d /etc/ssh/sshd_config"
    ssh "${ssh_args[@]}" $ip "sudo echo 'PermitRootLogin yes' | sudo tee -a /etc/ssh/sshd_config"
    ssh "${ssh_args[@]}" $ip sudo cat /etc/ssh/sshd_config | grep PermitRootLogin
  fi
  logger -st kubespray-$ip "install go"
  [[ $linux_family == 'debian' ]] && ssh "${ssh_args[@]}" $ip sudo apt-get install golang -y
  [[ $linux == 'centos' ]] && ssh "${ssh_args[@]}" $ip sudo yum install golang -y
  [[ $linux == 'ubuntu' ]] && logger -st kubespray-$ip "add kube user into ubuntu group"
  [[ $linux == 'ubuntu' ]] && ssh "${ssh_args[@]}" $ip sudo usermod -aG ubuntu kube
  logger -st kubespray-$ip "add ${PI} user into docker group"
  ssh "${ssh_args[@]}" $ip sudo usermod -aG docker $(id -un)
  if [[ (! -z $BASTION ) && ($BASTION == "$ip") ]]; then
    [[ $linux == 'ubuntu' ]] && logger -st kubespray-$ip "enable ubuntu firewall on Bastion host to allow IP packet forwarding"
    [[ $linux == 'ubuntu' ]] && ssh "${ssh_args[@]}" $ip sudo ufw --force enable
  else
    [[ $linux == 'ubuntu' ]] && logger -st kubespray-$ip "monitor ubuntu firewall status (should be allowing kubernetes forwarded ports)"
    [[ $linux == 'ubuntu' ]] && ssh "${ssh_args[@]}" $ip sudo ufw status
  fi
  ${TOPDIR}scripts/my_preset.sh --docker-setup $GVARS "${ssh_args[@]}" $ip
  logger -st "Get the kube journal from control host: ssh ${ssh_args[*]} journalctl -u kubelet"
done
logger -st $0 "Memory available on the node and master hosts, set lower if necessary $(${TOPDIR}scripts/my_preset.sh --memory-mb)"
cat roles/kubernetes/preinstall/defaults/main.yml | grep -b3 -a1 'minimal_node_memory_mb'
logger -st kubespray "****** K8s ansible : Run Playbook cluster.yml ******"
logger -st ${BASH_SOURCE[0]} "Install kubespray with the $CONFIG_FILE inventory file :${TOPDIR}scripts/my_playbook.sh -i $CONFIG_FILE --timeout=240 --ask-vault-pass -b --become-user=root cluster.yml"
