#!/usr/bin/env bash
# Usage: $ scripts/my_cluster.sh
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
IFS=' '
if [[ "$#" -gt 1 ]]; then IPS=$@; else while [[ -z $IPS ]]; do
	read -p "Please type in up to 6 local network ip${IFS}2°ip${IFS}3°ip...: (CTRL-C to exit) " -a ips
	echo -e "\n"
  if [[ ${#ips[@]} -gt 1 ]]; then
	if [[ $(cfrm_act "you've entered the correct ips addresses ${ips[0]} ${ips[1]} ${ips[2]} ${ips[3]} ${ips[4]} ${ips[5]}" 'n') > /dev/null ]]; then
		IPS=${ips[@]}
	fi
  else
      echo -e "Enter two or more valid IP addresses of the form X.X.X.X : X€[0;255] \n"
  fi
done; fi
logger -st kubespray "IPS=(${IPS[@]})\n"
YAML=inventory/mycluster/hosts.yaml
INI=inventory/mycluster/hosts.ini
HOSTS="-95.54.0.21 -95.54.0.22"
logger -st kubespray "****** K8s ansible : Generate $INI and $YAML ******"
python contrib/inventory_builder/inventory.py $HOSTS ${IPS[@]} print_cfg
[ $(cfrm_act "the machines are up and running" 'y') > /dev/null ] || exit 0
CONFIG_FILE=$INI python contrib/inventory_builder/inventory.py $HOSTS ${IPS[@]} print_cfg > $YAML
cat inventory/mycluster/group_vars/all/all.yml
[ $(cfrm_act "the options" 'y') > /dev/null ] || exit 0
cat inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml
[ $(cfrm_act "the kubernetes configuration" 'y') > /dev/null ] || exit 0

declare PI=ubuntu # replace 'pi' with 'ubuntu' or any other user
for ip in ${IPS[@]}; do
  logger -st kubespray-$ip "****** K8s ip : $PI@$ip ******"
  ssh-copy-id $PI@$ip;
  logger -st kubespray-$ip "configure sshd"
  ssh $PI@$ip "sudo echo 'PermitRootLogin yes' | sudo tee -a /etc/ssh/sshd_config";
  ssh $PI@$ip sudo cat /etc/ssh/sshd_config | grep PermitRootLogin;
  logger -st kubespray-$ip "install go"
  ssh $PI@$ip sudo apt-get install golang -y;
  logger -st kubespray-$ip "trusted repository"
  ssh $PI@$ip echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu bionic main" | sudo tee -a /etc/apt/sources.list
  ssh $PI@$ip echo "deb http://ppa.launchpad.net/projectatomic/ppa/ubuntu bionic main" | sudo tee -a /etc/apt/sources.list
  ssh $PI@$ip echo "deb http://ppa.launchpad.net/alexlarsson/flatpak/ubuntu bionic main" | sudo tee -a /etc/apt/sources.list
  logger -st kubespray-$ip "add kube user into ubuntu group"
  ssh $PI@$ip sudo usermod -a -G ubuntu kube;
  logger -st kubespray-$ip "disable ubuntu firewall"
  ssh $PI@$ip sudo ufw disable;
  # logger -st kubespray-$ip "Launchpad PPA repository keys"
  # ssh $PI@$ip sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367 &
  # ssh $PI@$ip sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8becf1637ad8c79d &
  # ssh $PI@$ip sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys c793bfa2fa577f07 &
done
cat roles/kubernetes/preinstall/tasks/0020-verify-settings.yml | grep -b2 'that: ansible_memtotal_mb'
logger -st kubespray "****** K8s ansible : Run Playbook cluster.yml ******"
scripts/my_playbook.sh -i $INI cluster.yml --timeout=60
#scripts/my_playbook.sh -i $YAML cluster.yml --timeout=60
for ip in ${IPS[@]}; do
   logger -st kubespray-$ip "****** K8s ip : $PI@$ip ******"
   logger -st kubespray-$ip "enable firewall"
   scripts/my_playbook.sh --firewall-setup $PI@$ip enable
   scripts/my_playbook.sh --firewall-setup $PI@$ip status

done
