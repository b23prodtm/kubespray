#!/usr/bin/env bash
export work_dir=$(echo $0 | awk -F'/' '{ print $1 }')'/'
[ ! -f .hap-wiz-env.sh ] && python3 ${work_dir}../library/hap-wiz-env.py $*
source .hap-wiz-env.sh
yaml='01-hostap.yaml'
clientyaml='01-cliwpa.yaml'
dns='/tmp/nameservers'
NP_ORIG=${work_dir}../../.netplan-store && sudo mkdir -p $NP_ORIG
logger -st netplan "disable cloud-init"
sudo mv -fv /etc/netplan/50-cloud-init.yaml $NP_ORIG
echo -e "network: { config: disabled }" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
if [ -f /etc/init.d/networking ]; then
    echo -e "${MARKER_BEGIN}
    iface lo inet loopback

    allow-hotplug eth0
    iface ${INT} inet dhcp
     network ${INTNET}.0

    allow-hotplug wlan0
    iface wlan0 inet manual
      address ${NET}.1
      network ${NET}.0
      netmask ${MASK}
${MARKER_END}" | sudo tee /etc/network/interfaces
else
  echo -e "${MARKER_BEGIN}
  network:
  version: 2
  renderer: networkd
  ethernets:
    ${INT}:
      dhcp4: yes
      dhcp6: yes
  wifis:
    wlan0:
      access-points:
        \"\":
          password:
      addresses: [${NET}.1/${MASKb}, '${NET6}1/${MASKb6}']
${MARKER_END}" | sudo tee /etc/netplan/$yaml
while [ "$#" -gt 0 ]; do case $1 in
  -r*|-R*)
    if [ -f /etc/init.d/networking ]; then
      sudo sed -i ${MARKERS}d /etc/network/interfaces
    else
      # ubuntu server
      logger -st netplan "move configuration to $NP_ORIG"
      sudo mv -fv /etc/netplan/* $NP_ORIG
      logger -st netplan "reset configuration to cloud-init"
      sudo mv -fv $NP_ORIG/50-cloud-init.yaml /etc/netplan
      sudo rm -fv /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    fi
    return;;
  --dns)
      echo ", $2" | sudo tee -a $nameservers;;
  --router)
    if [ -f /etc/init.d/networking ]; then
      echo -e "      gateway $2"
    else
      echo -e "      gateway4: $2" | sudo tee -a /etc/netplan/$yaml
    fi;;
  --router6)
    if [ -f /etc/init.d/networking ]; then
      # pass
    else
      echo -e "      gateway6: '$2'" | sudo tee -a /etc/netplan/$yaml
    fi;;
  -c*|--client)
    if [ -f /etc/init.d/networking ]; then
      echo -e "${MARKER_BEGIN}
iface lo inet loopback

allow-hotplug ${INT}
iface ${INT} inet dhcp

allow-hotplug wlan0
iface wlan0 inet dhcp
${MARKER_END}" | sudo tee /etc/network/interfaces
      sudo /etc/init.d/networking restart
    else
      logger -st netplan "/etc/netplan/$clientyaml was created"
        echo -e "${MARKER_BEGIN}network:
  version: 2
  renderer: networkd
  ethernets:
    ${INT}:
      dhcp4: yes
      dhcp6: yes
  wifis:
    wlan0:
      dhcp4: yes
      dhcp6: yes
      access-points:
        \"${SSID}\":
          password: \"${PAWD}\"
${MARKER_END}" | sudo tee /etc/netplan/$clientyaml
      logger -st netplan "apply $clientyaml"
      sudo netplan try --timeout 12
    fi
    return;;
  -h*|--help)
    echo "Usage: $0 [-r] [-c,--client]
    Initializes netplan.io networks plans and eventually restart them.
    -r
      Removes bridge interface
    --client
      Render as Wifi client to netplan"
      exit 1;;
   -b*|--bridge)
   if [ -f /etc/init.d/networking ]; then
   # ubuntu < 18.04
     echo -e "${MARKER_BEGIN}
   # Bridge setup
   auto lo br0

   auto br0
   iface br0 inet dhcp
     address 10.33.0.1
     network 10.33.0.0
     netmask 255.255.255.0
     nameservers 10.33.0.1$nameservers
   bridge_ports wlan0 ${INT}
   ${MARKER_END}" | sudo tee -a /etc/network/interfaces
     logger -st brctl "share the internet wireless over bridge"
     sudo brctl addbr br0
     sudo brctl addif br0 eth0 wlan0
   else
   # new 18.04 netplan server (DHCPd set to bridge)
   logger -st netplan "/etc/netplan/$yaml was created"
     echo -e "${MARKER_BEGIN}
     bridges:
       br0:
         dhcp4: yes
         dhcp6: yes
         addresses: [10.33.0.1/24, '2001:db8:1:46::1/64']
         nameservers:
           addresses: [10.33.0.1, '2001:db8:1:46::1'$nameservers]
         interfaces:
           - wlan0
           - eth0
   ${MARKER_END}" | sudo tee -a /etc/netplan/$yaml
   fi;;
   *);;
esac; shift; done
logger -st network "rendering configuration and restarting networks"
if [ -f /etc/init.d/networking ]; then
  sudo /etc/init.d/networking restart
else
  [ $(sudo netplan try --timeout 12) 2> /dev/null ] && exit 1
fi
logger -st ip "wakeup wlan0"
sudo ip link set dev wlan0 up
logger -st ip "redeem internet bridge"
sudo dhclient
