#!/usr/bin/env bash
usage="Usage: $0 [-n[ode]] user@host status|enable|disable|.."
node=0
host=''
iptables_reset='sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -F
sudo iptables -X'
ufw_rules='sudo ufw allow OpenSSH;
sudo ufw allow 6443/tcp;
sudo ufw allow 2379/tcp;
sudo ufw allow 2380/tcp;
sudo ufw allow 10250/tcp;
sudo ufw allow 10251/tcp;
sudo ufw allow 10252/tcp;
sudo ufw allow 10255/tcp;'
ufw_action=''
ufw_log='sudo ufw logging on;
sudo ufw logging medium'
while [ "$#" -gt 0 ]; do case $1 in
  -n*) # cluster-node
    shift
    node=1
    host=$1
    ufw_rules='sudo ufw allow OpenSSH;
    sudo ufw allow 30000:32767/tcp;
    sudo ufw allow 10250/tcp;
    sudo ufw allow 10255/tcp;
    sudo ufw allow 6783/tcp;'
    ;;
  enable)
    ssh $host "${iptables_reset}"
    ssh $host "${ufw_log}"
    ssh $host "${ufw_rules}"
    ;;
  disable)
    ssh $host "${iptables_reset}"
    ssh $host "${ufw_rules}"
    ;;
  *@*) host=$1
    ;;
  *)
    ssh $host 'sudo ufw '$* || echo $usage
    break;;
esac; shift; done
