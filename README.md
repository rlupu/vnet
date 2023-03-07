# vnet
<p>IP Virtual Network relying on net namespace technolgy for labs activities. </p>

<p>This script creates a virtual IPv4 network with a predefined topology composed of 3 interconected subnetwork 
domains required by further labs activities. The subnets are: 10.0.1.0/24, 10.0.2.0/24 and 10.0.3.0/24. 
Access to the Internet is provided via eth0 interface of the guest machine (WSL2). </br>
Run it with no arg to set up the virtual network.  </p>

<p>3 terminals will be launched relying on screen program (see screen documentation). </p>

<p>Developed and tested with Bash shell on WSL2 Debian platform. </p>



	      .1  (10.0.10/24)  .2	      .2  (10.0.2.0/24)  .1
	| H1 | ------------------ |  Router  | ------------------- | H2 |
	   veth0_h1     veth0_router	|   veth1_router          veth0_h2
					| veth2_router
					| .2
					| (10.0.3.0/24)
					|
					|
			     	   | Default |
					| eth0
					|
					|
					|
				    Internet
