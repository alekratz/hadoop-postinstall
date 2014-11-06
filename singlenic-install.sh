#!/bin/bash
# Hadoop single-nic machine IP forwarding install
# author: Alek Ratzloff
#
# Sets up IP forwarding for single-nic machines
# must be run as root!

function apply_subst {
  # Applies a substitution to a given file, and update with an optional status
  # usage: apply_subst regexp subst file [status]
  regexp=$1
  subst=$2
  file=$3
  
  # check to see if the pattern is even in the file
  grep "$file" -e "$regexp" > /dev/null
  if [[ $? -eq '0' ]]; then
    full_subst="s/$regexp/$subst/g"
    tmpfile=tmp_$(basename $file)
    cp $file $tmpfile
    sed "$full_subst" < $tmpfile > $file
    rm $tmpfile
  fi
}

function add_line {
  # Adds a line to a file. if that line exists by itself in the file, it will not be added.
  # usage: add_line line file
  line=$1
  file=$2

  if [[ -z $line || -z $file ]]; then
    echo "usage: add_line line file"
    exit 1
  fi
  
  grep $file -e "$line" > /dev/null
  if [[ $? -eq '1' ]]; then
    # if the line wasn't found, then append it to the end of the file
    echo $line >> $file
  fi
}

function add_subst {
  # Substitutes a line in a file if it exists, otherwise adds a new line to the file
  # usage: add_subst regexp subst line file

  regexp=$1
  subst=$2
  line=$3
  file=$4

  grep $file -e "$regexp" > /dev/null
  if [[ $? -ne '0' ]]; then
    # line doesn't exist in the file, so append
    add_line $line $file
  else
    apply_subst $regexp $subst $file
  fi
}

###############################################################################

if [[ $UID -ne '0' ]]; then
  echo 'Must be run as root!'
  exit 1
fi

if [[ $# -ne 2 ]]; then
  echo "usage: $0 network-card ip-address"
  exit 0
fi

card=$1
ipaddr=$2
card_config="/etc/sysconfig/network-scripts/ifcfg-$card"
apply_subst 'BOOTPROTO="none"' 'BOOTPROTO="static"' $card_config
apply_subst 'ONBOOT="no"' 'ONBOOT="yes"' $card_config
add_line "IPADDR=\"$ipaddr\"" $card_config
add_line 'NETMASK="255.255.255.0"' $card_config

pkill dhclient # kill dhclient because it will mess up the network if we don't
# also remove networkmanager
yum remove NetworkManager -y
# restart the network
service network restart
