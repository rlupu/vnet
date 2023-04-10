# vnet
<p>IP Virtual Network relying on net namespace technolgy for labs activities. </p>

<p>This script provides simple virtual IPv4 interconnected networks from json predefined topologies given as argument.
For each network entity a screen-based CLI is setup for management (see screen documentation).
Internet access could be enabled through masquerading (iptables) via host machine interface.</p>
<p>Commands tested: arp, sysctl (routers), ifconfig, route, ip, iptables, ping, tcpdump, scapy3, wget, snort, nmap.</p>
<p>Wrappers implemented for: rsyslog, nmap (more to be added).</p>
<p>Developed and tested with Bash v5.0.3(1) shell on WSL2 Debian platform. </p>
<h3>Usage:</h3>
<p>&nbps;&nbsp;&nbsp;sudo ./vnet.sh <json_file></p>

Configuration specified in net1.json sample file:

	      .1  (10.0.1.0/24)  .2	      .2  (10.0.2.0/24)  .1
	| H1 | ------------------ |  Router  | ------------------- | H2 |
	   veth0_h1     veth0_router	|   veth1_router      veth0_h2
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



Configuration specified in net2.json sample file:

	      .1  (10.0.1.0/24) .2	 .1 (10.0.2.0/24) .2       .1 (10.0.3.0/24) 2.

	| H1 | ------------------ |  R1  | ---------------- |  R2  | ---------------- | H2 |

	   veth0_h1    	    veth0_r1	veth1_r1      veth0_r2    veth1_r2	   veth0_h2
