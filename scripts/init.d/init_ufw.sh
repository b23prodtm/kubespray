#!/usr/bin/env bash
[ ! -f .hap-wiz-env.sh ] && python3 ${work_dir}../library/hap-wiz-env.py $*
source .hap-wiz-env.sh
while [ "$#" -gt 0 ]; do case $1 in
  -r*|-R*)
    sudo sed -i -e s/"${MARKERS}"//g /etc/ufw/before.rules
    sudo ufw disable
    return;;
  -c*|--client)
    return;;
  -h*|--help)
    echo "Usage: $0 [-r]
  Configure the firewall rules
  -r
    Removes all rules, disable firewall"
    exit 1;;
  *);;
esac; shift; done

logger -st ipv4 "enable ip forwarding v4"
sudo sed -i /net.ipv4.ip_forward/s/^\#// /etc/sysctl.conf /etc/ufw/sysctl.conf 2> hostapd.log
[ $(cat hostapd.log > /dev/null) ] && exit 1
logger -st ipv4 "enable ip forwarding v6"
sudo sed -i /net.ipv6.conf.all.forwarding/s/^\#// /etc/sysctl.conf /etc/ufw/sysctl.conf 2> hostapd.log
[ $(cat hostapd.log > /dev/null) ] && exit 1
logger -st ufw "configure firewall"
sudo sed -i /DEFAULT_FORWARD_POLICY/s/DROP/ACCEPT/g /etc/default/ufw 2> hostapd.log
[ $(cat hostapd.log > /dev/null) ] && exit 1
sleep 1
logger -st ufw "add ip masquerading rules"
echo -e "${MARKER_BEGIN}
# nat Table rules
*nat
:POSTROUTING ACCEPT [0:0]

# Forward traffic from wlan0 through eth0.
-A POSTROUTING -s ${NET}.0/${MASKb} -o ${INT} -j MASQUERADE
-A POSTROUTING -s ${NET6}0/${MASKb6} -o ${INT} -j MASQUERADE

# don't delete the 'COMMIT' line or these nat table rules won't be processed
COMMIT
${MARKER_END}" | sudo tee /tmp/input.rules
sudo sed -i s/^/"$(sudo cat /tmp/input.rules)"/ /etc/ufw/before.rules 2> hostapd.log
[ $(cat hostapd.log > /dev/null) ] && exit 1
sudo rm /tmp/input.rules
sleep 1
logger -st ufw "add packet ip forwarding"
echo -e "${MARKER_BEGIN}
-A ufw-before-forward -m state --state RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-forward -i wlan0 -s ${NET}.0/${MASKb} -o ${INT} -m state --state NEW -j ACCEPT
-A ufw-before-forward -i wlan0 -s ${NET}0/${MASKb6} -o ${INT} -m state --state NEW -j ACCEPT
${MARKER_END}
" | sudo tee /tmp/input.rules
sudo sed -i /"^\# End required lines"/a "$(sudo cat /tmp/input.rules)"/ /etc/ufw/before.rules 2> hostapd.log
[ $(cat hostapd.log > /dev/null) ] && exit 1
sudo rm /tmp/input.rules
sleep 1
logger -st ufw "allow ${NET}.0"
sudo ufw allow from ${NET}.0/${MASKb}
sudo ufw allow from ${NET6}0/${MASKb6}
sudo ufw enable
