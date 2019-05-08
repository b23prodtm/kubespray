#!/usr/bin/env bash
export work_dir=$(echo $0 | awk -F'/' '{ print $1 }')'/'
yaml='01-hostap.yaml'
clientyaml='01-cliwpa.yaml'
NP_ORIG=${work_dir}../../.netplan-store && sudo mkdir -p $NP_ORIG
logger -st netplan "disable cloud-init"
sudo mv -fv /etc/netplan/50-cloud-init.yaml $NP_ORIG
echo -e "network: { config: disabled }" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
export MARKER_BEGIN="# BEGIN GENERATED hostapd" MARKER_END="# END GENERATED hostapd" MARKERS="${MARKER_BEGIN}\\n.*\\n.*${MARKER_END}"
export CLIENT NET NET6 NET_start=15 NET_end=100 INT MASK=255.255.255.0 MASK6='ffff:ffff:ffff:ffff::' MASKb=24 MASKb6='64' SSID PAWD MODE CTY_CODE CHANNEL=0
while [ "$#" -gt 0 ]; do case $1 in
  -r*|-R*)
    sudo sed -i /bridge=br0/s/^/\#/ /etc/hostapd/hostapd.conf
    if [ -f /etc/init.d/networking ]; then
      sudo sed -i s/"${MARKERS}"//g /etc/network/interfaces
    else
      # ubuntu server
      logger -st netplan "move configuration to $NP_ORIG"
      sudo mv -fv /etc/netplan/* $NP_ORIG
      logger -st netplan "reset configuration to cloud-init"
      sudo mv -fv $NP_ORIG/50-cloud-init.yaml /etc/netplan
      sudo rm -fv /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    fi
    return;;
  -c*|--client)
    python ${work_dir}../library/psenv.py $*
    source .hap-wiz-env.sh && rm -f .hap-wiz-env.sh
    if [ -f /etc/init.d/networking ]; then
      echo -e "${MARKER_BEGIN}
auto lo br0
iface lo inet loopback

allow-hotplug ${INT}
iface ${INT} inet manual

allow-hotplug wlan0
iface wlan0 inet manual
${MARKER_END}" | sudo tee /etc/network/interfaces
      sudo /etc/init.d/networking restart
    else
      logger -st netplan "/etc/netplan/$clientyaml was created"
        echo -e "network:
  version: 2
  renderer: networkd
  ethernets:
    ${INT}:
      dhcp4: yes
  wifis:
    wlan0:
      access-points:
        \"${SSID}\":
          password: \"${PAWD}\"" | sudo tee /etc/netplan/$clientyaml
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
    *);;
esac; shift; done
if [ -f /etc/init.d/networking ]; then
# ubuntu < 18.04
  echo -e "${MARKER_BEGIN}
auto lo br0
iface lo inet loopback

allow-hotplug eth0
iface ${INT} inet manual
 network ${INTNET}.0

allow-hotplug wlan0
iface wlan0 inet dhcp
  address ${NET}.1
  network ${NET}.0
  netmask ${MASK}
# Bridge setup
auto br0
iface br0 inet dhcp
  address ${NET}.1
  network ${NET}.0
  netmask ${MASK}
  nameservers ${NET}.1
bridge_ports wlan0 ${INT}
${MARKER_END}" | sudo tee /etc/network/interfaces
  logger -st brctl "share the internet wireless over bridge"
  sudo brctl addbr br0
  sudo brctl addif br0 eth0 wlan0
else
# new 18.04 netplan server (DHCPd set to bridge)
logger -st netplan "/etc/netplan/$yaml was created"
  echo -e "network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
      dhcp6: no
  wifis:
    wlan0:
      access-points:
        \"\":
          password:
      addresses: [${NET}.2/${MASKb}, '${NET6}2/${MASKb6}']
  bridges:
    br0:
      dhcp4: yes
      dhcp6: yes
      addresses: [${NET}.1/${MASKb}, '${NET6}1/${MASKb6}']
      nameservers:
        addresses: [${NET}.1, '${NET6}1']
      interfaces:
        - wlan0
        - eth0" | sudo tee /etc/netplan/$yaml
fi
logger -st network "rendering configuration and restarting networks"
if [ -f /etc/init.d/networking ]; then
  sudo /etc/init.d/networking restart
else
  [ $(sudo netplan try --timeout 12) 2> /dev/null ] && exit 1
fi
