#!/usr/bin/env bash
if [ $USER != "root" ]
then
    echo -e "You need to run this script as root."
    exit 1
fi
if [ ! -f /etc/os-release ]
then
    echo -e "This script is made for Linux."
    [ $(which sw_vers) > /dev/null ] && sw_vers
    exit 1
fi
export work_dir=$(echo $0 | awk -F'/' '{ print $1 }')'/'
[ "$#" -lt 2 ] && python3 ${work_dir}../library/hap-wiz-env.py --help && exit 1
python3 ${work_dir}../library/hap-wiz-env.py $*
source .hap-wiz-env.sh
echo "Set Private Network $NET.0/$MASK"
echo "Set Private Network IPv6 ${NET6}0/$MASKb6"
echo "Set WAN Network $INTNET.0/$INTMASK"
echo "Set WAN Network IPv6 ${INTNET6}0/$INTMASKb6"
[ -z $CLIENT ] && rm -f hostapd.log
[ -z $CLIENT ] && touch hostapd.log
[ -z $CLIENT ] && [ -z $(which hostapd) ] && sudo apt-get -y install hostapd
[ -z $CLIENT ] && [ -z $(which brctl) ] && sudo apt-get -y install bridge-utils
[ -z $CLIENT ] && [ -z $(which dhcpd) ] && sudo apt-get -y install isc-dhcp-server
logger -st hostapd "remove bridge (br0) to wlan0"
source ${work_dir}init.d/init_net_if.sh -r
logger -st service "shutdown services"
sudo service wpa_supplicant stop
sudo service hostapd stop
sudo systemctl disable wpa_supplicant.service
source ${work_dir}init.d/init_dhcp_serv.sh -r
source ${work_dir}init.d/init_ufw.sh -r
[ -z $CLIENT ] && echo -e "### HostAPd will configure a public wireless network
IPv4 ${NET}.0/${MASKb} - ${SSID}
Example SSH'ed through bastion 'jump' host:
ssh -J $USER@$(ifconfig ${INT} | grep 'inet ' | awk '{ print $2 }') $USER@${NET}.15
-------------------------------
"
[ -z $CLIENT ] && sleep 3
[ -z $CLIENT ] && logger -t hostapd "Configure Access Point $SSID"
PSK_FILE=/etc/hostapd-psk
[ -z $CLIENT ] && echo -e "interface=wlan0       # the interface used by the AP
driver=nl80211
ssid=${SSID}

#ieee80211ac=1         # 5Ghz support
#hw_mode=a
#channel=36
# 2,4-2,5Ghz (HT 20MHz band)
#hw_mode=b
#channel=13
#ieee80211n=1          # 802.11n (HT 40 MHz) support
#hw_mode=g # 2,4-2,5Ghz (HT 40MHz band)
#channel=6
hw_mode=${MODE}
channel=${CHANNEL}  # 0 means the AP will search for the channel with the least interferences
#bridge=br0
ieee80211d=1          # limit the frequencies used to those allowed in the country
country_code=${CTY_CODE}       # the country code
wmm_enabled=1         # QoS support

#source: IBM https://www.ibm.com/developerworks/library/l-wifiencrypthostapd/index.html
auth_algs=1
wpa=2
wpa_psk_file=${PSK_FILE}
#wpa_passphrase=
wpa_key_mgmt=WPA-PSK
# Windows client may use TKIP
wpa_pairwise=CCMP TKIP
rsn_pairwise=CCMP

# Station MAC address -based authentication (driver=hostap or driver=nl80211)
# 0 = accept unless in deny list
# 1 = deny unless in accept list
# 2 = use external RADIUS server (accept/deny lists are searched first)
macaddr_acl=0

# Accept/deny lists are read from separate files
#accept_mac_file=/etc/hostapd/hostapd.accept
deny_mac_file=/etc/hostapd/hostapd.deny

# Beacon interval in kus (1.024 ms)
beacon_int=100

# DTIM (delivery trafic information message)
dtim_period=2

# Maximum number of stations allowed in station table
max_num_sta=255

# RTS/CTS threshold; 2347 = disabled (default)
rts_threshold=2347

# Fragmentation threshold; 2346 = disabled (default)
fragm_threshold=2346
" | sudo tee /etc/hostapd/hostapd.conf
[ -z $CLIENT ] && sudo touch /etc/hostapd/hostapd.deny
[ -z $CLIENT ] && echo -e "00:00:00:00:00:00 $(wpa_passphrase ${SSID} ${PAWD} | grep 'psk' | awk -F= 'FNR == 2 { print $2 }')" | sudo tee ${PSK_FILE}
[ -z $CLIENT ] && logger -st hostapd "configure Access Point as a Service"
[ -z $CLIENT ] && sudo sed -i -e /DAEMON_CONF=/s/^\#// -e /DAEMON_CONF=/s/=\".*\"/=\"\\/etc\\/hostapd\\/hostapd.conf\"/ /etc/default/hostapd 2> hostapd.log
[ -z $CLIENT ] && [ $(cat hostapd.log > /dev/null) ] && exit 1
[ -z $CLIENT ] && sudo sed -i -e /DAEMON_OPTS=/s/^\#// -e "/DAEMON_OPTS=/s/=\".*\"/=\"-i wlan0\"/" /etc/default/hostapd 2> hostapd.log
[ -z $CLIENT ] && [ $(cat hostapd.log > /dev/null) ] && exit 1
[ -z $CLIENT ] && sudo cat /etc/default/hostapd | grep "DAEMON"
[ -z $CLIENT ] && read -p "Do you wish to install Bridge Mode \
[PRESS ENTER TO START in Router mode now / no to use DNSMasq (old) / yes for Bridge mode] ?" SHARE
if [ -z $CLIENT ]; then case $SHARE in
#
# Bridge Mode
#
   'y'*|'Y'*)
      logger -st brctl "share internet connection from ${INT} to wlan0 over bridge"
      sudo sed -i /bridge=br0/s/^\#// /etc/hostapd/hostapd.conf
      source ${work_dir}init.d/init_net_if.sh --wifi '' '' --dns 8.8.8.8 --dns 9.9.9.9 --bridge
      ;;
  'n'*|'N'*)
    [ -z $(which dnsmasq) ] && sudo apt-get -y install dnsmasq
    logger -st dnsmasq "configure a DNS server as a Service"
    echo -e "bogus-priv
filterwin2k
# no-resolv
interface=wlan0    # Use the require wireless interface - usually wlan0
#no-dhcp-interface=wlan0
dhcp-range=${NET}.15,${NET}.100,${MASK},${MASKb}h
  # " | sudo tee /etc/dnsmasq.conf
    logger -st dnsmasq "start DNS server"
    sudo dnsmasq -x /var/run/dnsmasq.pid -C /etc/dnsmasq.conf
    sleep 3
    logger -st modprobe "enable IP Masquerade"
    sudo modprobe ipt_MASQUERADE
    sleep 1
    logger -st network "rendering configuration for dnsmasq mode"
    source ${work_dir}init.d/init_net_if.sh --wifi '' ''
    sudo systemctl unmask dnsmasq.service
    sudo systemctl enable dnsmasq.service
    sudo service dnsmasq start
    ;;
  *)
    logger -st network "rendering configuration for router mode"
    source ${work_dir}init.d/init_net_if.sh --wifi '' '' --dns 8.8.8.8 --dns 9.9.9.9
  ;;
esac;
    logger -st dhcpd  "configure dynamic dhcp addresses ${NET}.${NET_start}-${NET_end}"
    source ${work_dir}init.d/init_dhcp_serv.sh --dns 8.8.8.8 --dns 9.9.9.9 --router ${NET}.1 --router6 ${NET6}1
else
  source ${work_dir}init.d/init_net_if.sh --wifi $SSID $PAWD
fi
source ${work_dir}init.d/net_restart.sh $CLIENT
