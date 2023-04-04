#!/bin/bash

#
# Copyright (C) 2023 R. Lupu @ UPB 
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Contact:	rlupu@elcom.pub.ro
#
# Version:	0.3 (Debian)
#

regex_hostname="\"hostname\"[[:space:]]*:[[:space:]]*\"[a-z0-9]+\""
regex_ifname="\"ifname\"[[:space:]]*:[[:space:]]*\"[a-z0-9]+\""
regex_address="\"address\"[[:space:]]*:[[:space:]]*\"([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}|any)\""
regex_peer="\"peer\"[[:space:]]*:[[:space:]]*\"[a-z0-9@]+\""
regex_internet="\"internet\"[[:space:]]*:[[:space:]]*\"[a-z0-9]+\""
regex_netifs="\"netifs\"[[:space:]]*:[[:space:]]*\{[[:space:]]*(($regex_ifname|$regex_address|$regex_peer)[[:space:]]*,?[[:space:]]*)+\}"
regex_netifs_list="\"netifs\"[[:space:]]*:[[:space:]]*\[[[:space:]]*(\{[[:space:]]*(($regex_ifname|$regex_address|$regex_peer)[[:space:]]*,?[[:space:]]*)+\}[[:space:]]*,?[[:space:]]*)+\]"
regex_route="\"route\"[[:space:]]*:[[:space:]]*\{[[:space:]]*(($regex_address|\"gw\"[[:space:]]*:[[:space:]]*\"[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\")[[:space:]]*,?[[:space:]]*)+\}"
regex_endpoint="\"endpoint\"[[:space:]]*:[[:space:]]*\{[[:space:]]*(($regex_hostname|$regex_netifs|$regex_route)[[:space:]]*,?[[:space:]]*)+\}"
regex_router="\"router\"[[:space:]]*:[[:space:]]*\{[[:space:]]*(($regex_hostname|$regex_netifs_list|$regex_route)[[:space:]]*,?[[:space:]]*)+\}"
regex_gateway="\"gateway\"[[:space:]]*:[[:space:]]*\{[[:space:]]*(($regex_hostname|$regex_netifs_list|$regex_route|$regex_internet)[[:space:]]*,?[[:space:]]*)+\}"

function get_endpoints() {
	grep -zoiE $regex_endpoint $1 | xargs --null
}

function get_routers() {
	grep -zoiE $regex_router $1 | xargs --null
}

function get_gateways() {
	grep -zoiE $regex_gateway $1 | xargs --null
}

function get_hostname () { 
	grep -zoiE $regex_hostname $1 | cut -z -d ":" -f 2 | grep -zoiE "[0-9a-z]+" | xargs --null 
}

function get_ifnames(){
	grep -zoiE $regex_ifname $1 | cut -z -d ":" -f 2 | grep -zoiE "[a-z0-9]+" |xargs --null
}

function get_routes(){
	grep -zoiE $regex_route $1 | xargs -n 1 --null
}

function get_internet_if () { 
	grep -zoiE $regex_internet $1 | cut -z -d ":" -f 2 | grep -zoiE "[0-9a-z]+" | xargs --null 
}

function get_endpoint_id(){
	grep -zoiE "\"endpoint\"[[:space:]]*:[[:space:]]*\{[[:space:]]*((\"hostname\"[[:space:]]*:[[:space:]]*\"$1\"|$regex_netifs|$regex_route)[[:space:]]*.?[[:space:]]*)+\}" $2 | xargs --null
}

function get_router_id(){
	grep -zoiE "\"router\"[[:space:]]*:[[:space:]]*\{[[:space:]]*((\"hostname\"[[:space:]]*:[[:space:]]*\"$1\"|$regex_netifs_list|$regex_route)[[:space:]]*.?[[:space:]]*)+\}" $2 | xargs --null
}

function get_gateway_id(){
	grep -zoiE "\"gateway\"[[:space:]]*:[[:space:]]*\{[[:space:]]*((\"hostname\"[[:space:]]*:[[:space:]]*\"$1\"|$regex_netifs_list|$regex_route|$regex_internet)[[:space:]]*.?[[:space:]]*)+\}" $2 | xargs --null
}

function get_address_id() {
	grep -zoiE "\{[[:space:]]*((\"ifname\"[[:space:]]*:[[:space:]]*\"$1\"|$regex_address|$regex_peer)[[:space:]]*.?[[:space:]]*)+\}" $2 | grep -zoiE $regex_address | cut -z -d ":" -f 2 | grep -zoiE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | xargs --null
}

function get_mask_id() {
	grep -zoiE "\{[[:space:]]*((\"ifname\"[[:space:]]*:[[:space:]]*\"$1\"|$regex_address|$regex_peer)[[:space:]]*.?[[:space:]]*)+\}" $2 | grep -zoiE $regex_address | cut -z -d ":" -f 2 | grep -zoiE "/[0-9]{1,2}" | grep -zoiE "[0-9]{1,2}" | xargs --null
}

function get_peer_id() {
	grep -zoiE "\{[[:space:]]*((\"ifname\"[[:space:]]*:[[:space:]]*\"$1\"|$regex_address|$regex_peer)[[:space:]]*.?[[:space:]]*)+\}" $2 | grep -zoiE $regex_peer | cut -z -d ":" -f 2 | grep -zoiE "[a-z0-9]+\@[a-z0-9]+" | cut -z -d '@' --output-delimiter ' ' -f1,2  | xargs --null
}

function get_route_dst(){
	echo "$1" | grep -zoiE $regex_address | cut -z -d ":" -f 2 | grep -zoiE "([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}|any)" | xargs -n 1 --null
}

function get_route_gw(){
	echo "$1" | grep -zoiE "\"gw\"[[:space:]]*:[[:space:]]*\"[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\"" | cut -z -d ":" -f 2 | grep -zoiE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | xargs --null
}

function get_route_fields(){
	echo "$1" | \
	while read route; do
		get_route_dst "$route"
		get_route_gw "$route"
	done
}

