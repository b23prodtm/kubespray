#!/usr/bin/env bash
export work_dir=$(echo $0 | awk -F'/' '{ print $1 }')'/'
[ ! -f .hap-wiz-env.sh ] && python3 ${work_dir}../library/hap-wiz-env.py $*
source .hap-wiz-env.sh
while [ "$#" -gt 0 ]; do case $1 in
  -r*|-R*)
    sudo systemctl disable dnsmasq.service
    sudo service dnsmasq stop
    sudo service isc-dhcp-server stop
    sudo service isc-dhcp-server6 stop
    sudo systemctl disable isc-dhcp-server.service
    sudo systemctl disable isc-dhcp-server6.service
    return;;
  -h*|--help)
    echo "
Usage: $0 [-r]
       $0 [-l, --leases <hostname>]
  Initializes DHCP services (without dnsmasq)
  -r
    Disable all dhcp (also with dnsmasq) services
  -l <hostname>
    Prints ethernet mac address corresponding to the specified host DHCP lease. \
    New fixed addresses can be added to /etc/dhcpd/dhcp.conf, /etc/dhcpd/dhcp6.conf."
    exit 1;;
  -l*|--leases*)
    export LEASE_HOST=$2 LEASE=$(cat /var/lib/dhcp/dhcpd.leases | grep -C4 $2 | grep -m1 "hardware ethernet" | awk -F' ' '{print $3}');;
  *);;
esac; shift; done
echo -e "option domain-name-servers ${NET}.1, 8.8.8.8, 8.8.4.4;

default-lease-time 600;
max-lease-time 7200;

authoritative;

log-facility local7;

subnet ${INTNET}.0 netmask ${INTMASK} {}
subnet ${NET}.0 netmask ${MASK} {
#option domain-name "wifi.localhost";
option routers ${NET}.1; #hostapd wlan0
option subnet-mask ${MASK};
option broadcast-address ${NET}.0; # dhcpd
range ${NET}.${NET_start} ${NET}.${NET_end};
# Example for a fixed host address
#      host ${LEASE_HOST} { # host hostname
#      hardware ethernet ${LEASE} # hardware ethernet 00:00:00:00:00:00;
#        fixed-address ${NET}.15; }
}
" | sudo tee /etc/dhcp/dhcpd.conf
[ ! -z ${LEASE_HOST} ] && sudo sed -i -e /"host hostname"/s/^\#// -e /"hardware ethernet"/s/^\#// -e /"fixed-address"/s/^\#// /etc/dhcp/dhcpd.conf
echo -e "option dhcp6.name-servers ${NET6}1;

default-lease-time 600;
max-lease-time 7200;

authoritative;

log-facility local7;

subnet6 ${INTNET6}0/${INTMASKb6} {}
subnet6 ${NET6}0/${MASKb6} {
#option dhcp6.domain-name "wifi.localhost";
range6 ${NET6}${NET_start} ${NET6}${NET_end};
# Example for a fixed host address
#      host ${LEASE_HOST} { # host hostname
#      hardware ethernet ${LEASE} # hardware ethernet 00:00:00:00:00:00;
#        fixed-address ${NET6}15; }
}
" | sudo tee /etc/dhcp/dhcpd6.conf
[ ! -z ${LEASE_HOST} ] && sudo sed -i -e /"host hostname"/s/^\#// -e /"hardware ethernet"/s/^\#// -e /"fixed-address"/s/^\#// /etc/dhcp/dhcpd6.conf
sudo sed -i -e "s/INTERFACESv4=\".*\"/INTERFACESv4=\"br0\"/" /etc/default/isc-dhcp-server
sudo sed -i -e "s/INTERFACESv6=\".*\"/INTERFACESv6=\"br0\"/" /etc/default/isc-dhcp-server
sudo cat /etc/default/isc-dhcp-server
sleep 1
logger -st dhcpd "start DHCP server"
sudo systemctl unmask isc-dhcp-server.service
sudo systemctl enable isc-dhcp-server.service
sudo service isc-dhcp-server start
sudo systemctl unmask isc-dhcp-server6.service
sudo systemctl enable isc-dhcp-server6.service
sudo service isc-dhcp-server6 start
