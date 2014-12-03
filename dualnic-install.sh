#!/bin/bash
# Hadoop dual-nic machine IP forwarding install
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

################################################################################

if [[ $UID -ne '0' ]]; then
  echo 'Must be run as root!'
  exit 1
fi

if [[ $# -ne 2 ]]; then
  echo "usage: $0 card-internal card-external"
  echo "where card-internal is the network card used for the internal network and card-external is the card used for the external network"
  exit 0
fi

# On the current machine, internal is enp12s2, external is enp11s0
internal=$1
external=$2

add_line 'net.ipv4.ip_forward=1' /etc/sysctl.conf
# Mask external requests from local LAN nodes with the IP address of the gateway

# CentOS 6+ uses firewalld by default. Unfortunately, firewalld is a crock of convoluted BS, so we're going to stick to tried-and-true IP tables.
# Detect if we need to disable firewalld and enable iptables
systemctl status firewalld > /dev/null
if [[ $? -eq 0 ]]; then
  echo "Stopping and disabling firewalld..."
  systemctl stop firewalld
# mask will make sure that firewalld will never ever run unless we explicitly tell it to
  systemctl mask firewalld
  echo "Starting and enabling iptables..."
  systemctl enable iptables
  systemctl start iptables
fi

in_fwd_rule="FORWARD -i $internal -j ACCEPT"
out_fwd_rule="FORWARD -o $external -j ACCEPT"
drop_icmp_rule="FORWARD -j REJECT --reject-with icmp-host-prohibited"
masq_rule="POSTROUTING -o $external -j MASQUERADE"

# Get whether or not some rules need to be added
# if the in or out forward rules haven't been defined, then we need to get rid of the drop_icmp rule and add it again
iptables -S FORWARD | grep -e "$in_fwd_rule" > /dev/null
in_fwd_exists=$?
iptables -S FORWARD | grep -e "$out_fwd_rule" > /dev/null
out_fwd_exists=$?

if (( $in_fwd_exists == 1 || $out_fwd_exists == 1)); then
# one of the rules does not exist in the iptables, so delete the icmp drop rule, delete both of the rules (if possible)
# and re-add the icmp drop rule
  echo "Adding iptables forwarding rules"
  iptables -D $drop_icmp_rule > /dev/null # we really don't care if it fails or not
  iptables -D $in_fwd_rule > /dev/null
  iptables -D $out_fwd_rule > /dev/null
  iptables -A $in_fwd_rule
  iptables -A $out_fwd_rule
  iptables -A $drop_icmp_rule
fi

# now check to see if the masquerade rule exists
iptables -t nat -S POSTROUTING | grep -e "$masq_rule" > /dev/null
masq_exists=$?

if (( $masq_exists == 1 )); then
  echo "Adding iptables masquerade rules"
# masquerade rule does not exist, so add it here
  iptables -t nat -A $masq_rule
fi
