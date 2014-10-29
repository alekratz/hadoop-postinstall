#!/bin/bash
# Hadoop dual-nic machine IP forwarding BS install
# author: Alek Ratzloff
#
# Sets up IP forwarding for dual-nic machines
# must be run as root!

if [[ $# -ne 2 ]]; then
  echo "usage: $0 card-in card-out"
  exit 0
fi


