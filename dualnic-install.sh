#!/bin/bash
# Hadoop dual-nic machine IP forwarding BS install
# author: Alek Ratzloff
#
# Sets up IP forwarding for dual-nic machines
# must be run as root!

function add_line {
  # Adds a line to a file. if that line exists by itself in the file, it will not be added.
  # usage: add_line line file
  line=$1
  file=$2

  if [[ -z $line || -z $file ]]; then
    echo "usage: add_line line file"
    exit 1
  fi

  echo -n $status
  grep $file -e "$line" > /dev/null
  if [[ $? -eq '1' ]]; then
    # if the line wasn't found, then append it to the end of the file
    echo $line >> $file
  fi
}

if [[ $# -ne 2 ]]; then
  echo "usage: $0 card-internal card-external"
  echo "where card-internal is the network card used for the internal network and card-external is the card used for the external network"
  exit 0
fi

# On the current machine, internal is enp12s2, external is enp11s0
internal=$1
external=$2

iptables -A FORWARD -i $internal -j ACCEPT
iptables -A FORWARD -o $external -j ACCEPT
add_line 'net.ipv4.ip_forward=1' /etc/sysctl.conf
# Mask external requests from local LAN nodes with the IP address of the gateway
echo "iptables -t nat -A POSTROUTING -o $external -j MASQUERADE" >> ~/.bashrc
