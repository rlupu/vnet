#!/bin/bash

regex_hostname="\"hostname\"[[:space:]]*:[[:space:]]*\"[a-z0-9]+\""
regex_ifname="\"ifname\"[[:space:]]*:[[:space:]]*\"[a-z0-9]+\""
regex_address="\"address\"[[:space:]]*:[[:space:]]*\"([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}|any)\""
regex_peer="\"peer\"[[:space:]]*:[[:space:]]*\"[a-z0-9@]+\""
regex_netifs="\"netifs\"[[:space:]]*:[[:space:]]*\{[[:space:]]*(($regex_ifname|$regex_address|$regex_peer)[[:space:]]*,?[[:space:]]*)+\}"
regex_netifs_list="\"netifs\"[[:space:]]*:[[:space:]]*\[[[:space:]]*(\{[[:space:]]*(($regex_ifname|$regex_address|$regex_peer)[[:space:]]*,?[[:space:]]*)+\}[[:space:]]*,?[[:space:]]*)+\]"

regex_route="\"route\"[[:space:]]*:[[:space:]]*\{[[:space:]]*(($regex_address|\"gw\"[[:space:]]*:[[:space:]]*\"[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\")[[:space:]]*,?[[:space:]]*)+\}"

regex_endpoint="\"endpoint\"[[:space:]]*:[[:space:]]*\{[[:space:]]*(($regex_hostname|$regex_netifs|$regex_route)[[:space:]]*,?[[:space:]]*)+\}"
regex_router="\"router\"[[:space:]]*:[[:space:]]*\{[[:space:]]*(($regex_hostname|$regex_netifs_list|$regex_route)[[:space:]]*,?[[:space:]]*)+\}"


function get_endpoints() {
	grep -zoiE $regex_endpoint $1 | xargs --null
}

function get_routers() {
	grep -zoiE $regex_router $1 | xargs --null
}

function get_hostname () { 
	grep -zoiE $regex_hostname $1 | cut -z -d ":" -f 2 | grep -zoiE "[0-9a-z]+" | xargs --null 
}

