# vnet
<p>IP Virtual Network relying on net namespace technolgy for labs activities. </p>

<p>This script creates the virtual IPv4 network with a predefined topology composed of 3 interconnected subnetwork 
domains required by further labs activities. The subnets are: 10.0.1.0/24, 10.0.2.0/24 and 10.0.3.0/24. 
Access to the Internet is provided via eth0 interface of the Host machine. </br>
Run it with no arg to set up the virtual network.  </p>

<p>Three virtual terminals will be launched relying on screen program (see screen documentation), named H1-term,
H2-term and R-term, respectively. So far, the following commands are supported: ifconfig, route, ip, iptables, 
ping, tcpdump, scapy3, hping3, wget, ssh (further cmds could be easily added).</p>

<p>Developed and tested with Bash v5.0.3(1) shell on WSL2 Debian platform. </p>


	      .1  (10.0.1.0/24)  .2	      .2  (10.0.2.0/24)  .1
	| H1 | ------------------ |  Router  | ------------------- | H2 |
	   veth0_h1     veth0_router	|   veth1_router       eth0_h2
					| veth2_router
					| .2
					| (10.0.3.0/24)
					|
					| veth0
			     	    | Host |
					| eth0
					|
					|
					|
				    Internet
