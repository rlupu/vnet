#!/bin/bash

# TODO:		1) ... 
#
# Author:	rlupu @ UPB
# Date:		Feb-Mar. 2023
# Version:	0.2 (Debian)


while getopts ":hlr" option; do
        case $option in
                h) #display help
                   echo "This script provides the management functions for the virtual network for SIRC labs. "
		   echo "It is implemented based on linux namespace technology. Run it w/o any arg to set up "
		   echo "the required net domains and related IP interconnectivity. 3 terms will be launched "
		   echo "relying on screen program (see screen documentation). "
		   echo "Usage: vnet.sh [ {-h, -l, -r} ] "
		   echo -e "   -h\tThis help."
		   echo -e "   -l\tList all user-defined net namespaces."
		   echo -e "   -r\tRemove all virtual nets and terms.\n"
                   exit
		   ;;
		l) #list all existing namespaces, terms, etc.
		   nsfound=$(ip netns list)

		   if ! [ -z "$nsfound" ]; then
       			echo -n "Found namespaces: "
        		echo $nsfound
		   else
			echo "No Namespaces found."
		   fi

		   if [ $(id -u) -eq 0 ]; then
		   	screen -ls
		   fi
		   exit
		   ;;
                r) #remove all namespaces
		   if [ $(id -u) -ne 0 ]; then
			echo "Should have root privileges!"
			exit
		   fi
		   echo -n "Removing all links, net i/f, namespaces and terms ..."
		   ip netns exec Router ip link del veth0_router
		   ip netns exec Router ip link del veth1_router
		   ip netns exec Router ip link del veth2_router
                   ip netns list | cut -d ' ' -f 1 | xargs -n 1 ip netns del
		   pkill screen
                   echo "done."
                   exit
		   ;;
        esac
done


if [ $(id -u) -ne 0 ]; then
	echo "Should have root privileges!"
	exit
fi

echo "Create virtual network entities (i.e. namespaces):"
echo -ne "\tH1\t...... "
ip netns add H1 2> /dev/null
if [ $? -eq 0 ]; then
        echo -e "\tdone"
else
        echo -e "\texists"
fi

echo -ne "\tRouter\t...... "
ip netns add Router 2> /dev/null
if [ $? -eq 0 ]; then
        echo -e "\tdone"
else
        echo -e "\texists"
fi

echo -ne "\tH2\t...... "
ip netns add H2 2> /dev/null
if [ $? -eq 0 ]; then
        echo -e "\tdone"
else
        echo -e "\texists"
fi


echo -n "Create and attach related network interfaces..... "
ip link add veth0_h1 type veth peer name veth0_router
ip link add veth0_h2 type veth peer name veth1_router
ip link add veth0 type veth peer name veth2_router

#attach interfaces accordingly
ip link set veth0_h1 netns H1 
ip link set veth0_router netns Router 

ip link set veth0_h2 netns H2 
ip link set veth1_router netns Router 

ip link set veth2_router netns Router 
echo "done."    

echo -n "Configure IP addresses, routing tables, enable forwarding ..... "
ip netns exec H1 ip address add 10.0.1.1/24 dev veth0_h1
ip netns exec H1 ip link set dev veth0_h1 up

ip netns exec H2 ip address add 10.0.2.1/24 dev veth0_h2
ip netns exec H2 ip link set dev veth0_h2 up

ip netns exec Router ip address add 10.0.1.2/24 dev veth0_router
ip netns exec Router ip link set dev veth0_router up
ip netns exec Router ip address add 10.0.2.2/24 dev veth1_router
ip netns exec Router ip link set dev veth1_router up
ip netns exec Router ip address add 10.0.3.2/24 dev veth2_router
ip netns exec Router ip link set dev veth2_router up

ip address add 10.0.3.1/24 dev veth0
ip link set dev veth0 up

ip netns exec H1 ip route add default via 10.0.1.2
ip netns exec H2 ip route add default via 10.0.2.2
ip netns exec Router ip route add default via 10.0.3.1

ip route add 10.0.1.0/24 via 10.0.3.2
ip route add 10.0.2.0/24 via 10.0.3.2

ip netns exec Router /bin/bash -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
echo "1" > /proc/sys/net/ipv4/ip_forward
echo "done."    

echo -n "Enable masquerading for Internet access via eth0 (default) ..... "
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
echo "done."    

echo "Launch CLIs for management:"
screen -dmS H1-term bash -c "function ip() { /sbin/ip netns exec H1 /sbin/ip -c \$* ; } ; \
	function route() { /sbin/ip netns exec H1 /sbin/route \$* ; } ; \
	function ifconfig() { /sbin/ip netns exec H1 /sbin/ifconfig \$* ; } ; \
	function iptables() { /sbin/ip netns exec H1 /sbin/iptables \$* ; } ; \
	function ping() { /sbin/ip netns exec H1 /bin/ping \$* ; } ; \
	function tcpdump() { /sbin/ip netns exec H1 /usr/sbin/tcpdump \$* ; } ; \
	function hping3() { /sbin/ip netns exec H1 /usr/sbin/hping3 \$* ; } ; \
	function scapy3() { /sbin/ip netns exec H1 /usr/bin/scapy3 \$* ; } ; \
	function wget() { /sbin/ip netns exec H1 /usr/bin/wget \$* ; } ; \
	function ssh() { /sbin/ip netns exec H1 /usr/bin/ssh \$* ; } ; \
	export -f ip ping route ifconfig iptables tcpdump hping3 scapy3 wget ssh; \
	export PS1=\"Host 1#\"; \
	bash --norc"
echo -e "\tH1-term\t......\tup"

screen -dmS R-term bash -c "function ip() { /sbin/ip netns exec Router /sbin/ip -c \$* ; } ; \
	function route() { /sbin/ip netns exec Router /sbin/route \$* ; } ; \
	function ifconfig() { /sbin/ip netns exec Router /sbin/ifconfig \$* ; } ; \
	function iptables() { /sbin/ip netns exec Router /sbin/iptables \$* ; } ; \
	function ping() { /sbin/ip netns exec Router /bin/ping \$* ; } ; \
	function tcpdump() { /sbin/ip netns exec Router /usr/sbin/tcpdump \$* ; } ; \
	function hping3() { /sbin/ip netns exec Router /usr/sbin/hping3 \$* ; } ; \
	function scapy3() { /sbin/ip netns exec Router /usr/bin/scapy3 \$* ; } ; \
	function wget() { /sbin/ip netns exec Router /usr/bin/wget \$* ; } ; \
	function ssh() { /sbin/ip netns exec Router /usr/bin/ssh \$* ; } ; \
	export -f ip ping route ifconfig iptables tcpdump hping3 scapy3 wget ssh; \
	export PS1=\"Router#\"; \
	bash --norc"
echo -e "\tR-term\t......\tup"

screen -dmS H2-term bash -c "function ip() { /sbin/ip netns exec H2 /sbin/ip -c \$* ; } ; \
	function route() { /sbin/ip netns exec H2 /sbin/route \$* ; } ; \
	function ifconfig() { /sbin/ip netns exec H2 /sbin/ifconfig \$* ; } ; \
	function iptables() { /sbin/ip netns exec H2 /sbin/iptables \$* ; } ; \
	function ping() { /sbin/ip netns exec H2 /bin/ping \$* ; } ; \
	function tcpdump() { /sbin/ip netns exec H2 /usr/sbin/tcpdump \$* ; } ; \
	function hping3() { /sbin/ip netns exec H2 /usr/sbin/hping3 \$* ; } ; \
	function scapy3() { /sbin/ip netns exec H2 /usr/bin/scapy3 \$* ; } ; \
	function wget() { /sbin/ip netns exec H2 /usr/bin/wget \$* ; } ; \
	function ssh() { /sbin/ip netns exec H2 /usr/bin/ssh \$* ; } ; \
	export -f ip ping route ifconfig iptables tcpdump hping3 scapy3 wget ssh; \
	export PS1=\"Host 2#\"; \
	bash --norc"
echo -e "\tH2-term\t......\tup"

echo "(GO INTO: sudo screen -r <name>; GO OUT: CTRL-a d; CLOSE: exit) "
echo "done."


