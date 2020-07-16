#!/usr/bin/env bash
TOPDIR=$(cd "$(dirname "${BASH_SOURCE[@]}")/.." && pwd)
function set_yml_vars() {
  [ "$#" -lt 3 ] && echo -e "Usage: $0 -s <path/to/thevars.yml> <var_name> <value>..."
  silent=""
  [ $1 == "-s" ] && shift && silent="-s"
  [ ! -f $1 ] && logger -st $0 "File $1 not found" && exit 1
  python3 "${TOPDIR}/library/yaml-tool.py" "$silent" "$@"
}
function ask_vault() {
  [ "$#" -lt 2 ] && echo -e "Usage: $0 <group> <ansible-vault command>" && exit 1
  group=$1
  shift
  printf "Vault File %s \nPress [ENTER] to continue." "${GVARS}/${group}/vault.yml"
  if [ ! -f "$GVARS/${group}/vault.yml" ]; then
    if [ "$(cfrm_act "You wish to create the vault with new passwords ?" 'y')" ]; then
      cat << EOF | cat
---
# example password vault for group ${group}
ansible_password: raspberry
EOF
      ansible-vault create "$GVARS/${group}/vault.yml"
    fi
  else
      ansible-vault "$@" "$GVARS/${group}/vault.yml"
  fi
}
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
INV=${INV:-"${TOPDIR}/inventory/mycluster/inventory.yaml"}
HOSTS=$(dirname $INV)/hosts.yaml
defaults=(--become --become-user=root --ask-vault-pass --timeout=240 --flush-cache -e dns_early=true)
options=()
usage=("" \
"Usage: $0   [-i,--inventory <inventory/path/to/inventory.yaml>] " \
"            [-H, --hosts <inventory/path/to/hosts.yaml>] <yaml>" \
"            [--edit-vault <inventory/path/to/group/vault.yml>]" \
"            [ansible-playbook options]" \
"            <yaml>:" \
"cluster.yml builds up a new the cluster from the inventory (CONFIG_FILE)." \
"reset.yml   resets all hosts off and the cluster is teared down." \
"scale.yml   scales up or down the cluster as defined by some" \
"            change in the inventory." \
"  options: (${defaults[@]}) if one option is used, the others must be there or it gets erased." \
"")
[ "$#" -lt 1 ] && printf "%s\n" "${usage[@]}" && exit 0
vault_cmd="view"
while [ "$#" -gt 0 ]; do case $1 in
  --edit-vault)
    vault_cmd="edit $*";;
  -i*|--inventory)
    INV="$2"
    HOSTS="$(dirname $INV)/hosts.yaml"
    shift;;
  -H*|--hosts)
    HOSTS=$2;;
  -h*|--help)
    printf "%s\n" "${usage[@]}"
    exit 0;;
  -[-]?b*|--ask*|--timeout*)
    options=("${options[@]}" "$1")
    defaults=();;
  *) options=("${options[@]}" "$1");;
esac; shift; done
cat $HOSTS
export CONFIG_FILE="$INV"
GVARS="$(dirname $CONFIG_FILE)/group_vars"
if [ "$(cfrm_act "You wish to update the CONFIG_FILE=$CONFIG_FILE with $HOSTS ?" 'n')" ]; then
    CONFIG_FILE="$INV"
    python3 "${TOPDIR}/contrib/inventory_builder/inventory.py" load "$HOSTS"
    ask_vault "bastion" "$vault_cmd" "securized" "$vault_cmd"
    ansible -i "$INV" --ask-vault-pass -m ping all
fi
logger -st $0 "$(hostname) must be connected to the ""same network"" than the master/bastion host"
logger -st $0 "After ansible-playbook . reset.yml, a 'bare metal' reboot the cluster may be required..."
logger -st $0 "Reminder: ""A functional cluster's good DNS configuration"""
logger -st $0 "If a TASK failed on timeouts, try again with longer delays the kubernetes cluster"
logger -st $0 "Known TASKs that take more time : [Starting of Calico/Flannel/.. kube controllers], [Kubernetes Apps | Start Resources]..."
logger -st $0 "Run ansible-playbook -i $INV ${defaults[*]} ${options[*]}" \
&& ansible-playbook -i "$INV" "${defaults[@]}" "${options[@]}" \
&& logger -st $0 "Next call must be $TOPDIR/extra_scripts/my_kubectl.sh -h"
logger -st $0 "It's going to take past half an hour per host to complete the cluster boot process, pods... On failure you can reset cluster "
logger -st $0 "--flush-cache --timeout=240 reset.yml --ask-vault-pass -b"
logger -st $0 "Now that's finished and it's time to control the kube. Call  sudo $TOPDIR/extra_scripts/my_kubectl.sh -i $INV --help to get help."
