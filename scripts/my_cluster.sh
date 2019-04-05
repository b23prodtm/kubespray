#!/usr/bin/env bash
#
# Update Ansible inventory file with inventory builder . Single master IP is possible, see nodes with bastion
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
logger -t kubespray "IPS=(${IPS[@]})\n"
YAML=inventory/mycluster/hosts.yaml
HOSTS="-95.54.0.21 -95.54.0.22"
python contrib/inventory_builder/inventory.py $HOSTS ${IPS[@]} print_cfg
[ $(cfrm_act "the machines are up and running" 'y') > /dev/null ] || exit 0
python contrib/inventory_builder/inventory.py $HOSTS ${IPS[@]} print_cfg > $YAML
cat inventory/mycluster/group_vars/all/all.yml
[ $(cfrm_act "the options" 'y') > /dev/null ] || exit 0
cat inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml
[ $(cfrm_act "the kubernetes configuration" 'y') > /dev/null ] || exit 0
	
declare PI=ubuntu # replace 'pi' with 'ubuntu' or any other user
for ip in ${IPS[@]}; do
  logger -t kubespray-$ip "****** K8s ip : $PI@$ip ******"
  ssh-copy-id $PI@$ip;    
  logger -t kubespray-$ip "configure sshd"
  ssh $PI@$ip sudo bash -c "echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config";
  ssh $PI@$ip sudo cat /etc/ssh/sshd_config | grep PermitRootLogin;
  logger -t kubespray-$ip "install go"
  ssh $PI@$ip sudo apt-get install golang -y;
  ssh $PI@$ip sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367;
  ssh $PI@$pi sudo usermod -a -G ubuntu kube;
  logger -t kubespray-$ip "disable firewall"
  ssh $PI@$pi sudo ufw disable;
done
cat roles/kubernetes/preinstall/tasks/0020-verify-settings.yml | grep -b2 'that: ansible_memtotal_mb'
scripts/my_playbook.sh -i $YAML cluster.yml --timeout=60
for ip in ${IPS[@]}; do
   scripts/my_playbook.sh --setup-firewall $PI@$pi
   logger -t kubespray-$ip "enable firewall"
   ssh $PI@$pi sudo ufw enable;        
done
