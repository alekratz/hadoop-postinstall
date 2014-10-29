#!/bin/bash
# Hadoop node post-install
# author: Alek Ratzloff
#
# performs post-install operations on a hadoop cluster to correctly configure the machine
# must be run as root!

# this may change
SELINUX_DIR=/etc/selinux
SSHD_DIR=/etc/ssh
BACKUP_DIR=.installbackups
PATCH_DIR=.installpatches

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)
COLS=80

SYSFILES=("$SELINUX_DIR/config" "$SSHD_DIR/sshd_config" "/etc/fstab" "/etc/sysctl.conf" "/etc/security/limits.conf" "/etc/sysconfig/network")

NAMENODE=192.168.1.1

HOSTS='
# Hadoop cluster info
192.168.1.1		192.168.1.1		hydrogen
192.168.1.2		192.168.1.2		helium
192.168.1.3		192.168.1.3		lithium
192.168.1.4		192.168.1.4		beryllium
192.168.1.5		192.168.1.5		boron
192.168.1.6		192.168.1.6		carbon
192.168.1.7		192.168.1.7		nitrogen
192.168.1.8		192.168.1.8		oxygen
'

function print_fail {
  # usage: print_fail
  # offset=$1
  #col=$(($COLS - $offset))
  #printf "%s%*s%s\n" "$RED" $col '[ FAIL ]' "$NORMAL"
  echo -e " $RED [ FAIL ]$NORMAL"
}

function print_ok {
  # usage: print_ok
  #offset=$1
  #col=$(($COLS - $offset))
  #printf "%s%*s%s\n" "$GREEN" $col '[ OK ]' "$NORMAL"
  echo -e " $GREEN [ OK ]$NORMAL"
}

function print_skip {
  # usage: print_skip
  #offset=$1
  #col=$(($COLS - $offset))
  #printf "%s%*s%s\n" "$GREEN" $col '[ SKIP ]' "$NORMAL"
  echo -e " $GREEN [ SKIP ]$NORMAL"
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
  status="Appending $line to $file..."

  echo -n $status
  grep $file -e "$line" > /dev/null
  if [[ $? -eq '1' ]]; then
    # if the line wasn't found, then append it to the end of the file
    echo $line >> $file
    print_ok
  else
    print_skip
  fi
}

function apply_subst {
  # Applies a substitution to a given file, and update with an optional status
  # usage: apply_subst regexp subst file [status]
  regexp=$1
  subst=$2
  file=$3
  if [[ -z $4 ]]; then
    status="Replacing pattern '$regexp' with '$subst' in $file"
  else
    status=$4
  fi

  echo -n "$status"
  # check to see if the pattern is even in the file
  grep "$file" -e "$regexp" > /dev/null
  if [[ $? -ne '0' ]]; then
    # if not, then continue
    print_skip
  else
    full_subst="s/$regexp/$subst/g"
    tmpfile=tmp_$(basename $file)
    cp $file $tmpfile
    sed "$full_subst" < $tmpfile > $file
    rm $tmpfile
    print_ok
  fi
}

function backup_file {
# Copies a specified file into the backups folder.
# usage: backup_file filename
  mkdir $BACKUP_DIR -p
  path=$1
  file=$(basename $path)
  status="Backing up $path..."
  echo -n $status

  if [[ -e "$BACKUP_DIR/$file" ]]; then
    print_skip
  elif [[ -e "$path" ]]; then
    cp $path $BACKUP_DIR/$file > /dev/null
    print_ok
  else
    fail_status="could not copy $file."
    echo -n $fail_status
    print_fail
  fi
}

function get_yesno {
# Gets user input as either a 'yes' or a 'no' and stores that result in the specified variable
# usage: get_yesno prompt variable
  prompt=$1
  variable=$2
  response=''
  while [[ "$response" = "" ]]; do
    read -r -p "$prompt" response
    response=${response,,} # tolower
    if [[ $response =~ ^(yes|y)$ ]]; then
      eval "$variable='y'"
    elif [[ $response =~ ^(no|n)$ ]]; then
      eval "$variable='n'"
    else
      response=''
    fi
  done
}

function install {
# Verify that user is root
  if [[ $UID -ne '0' ]]; then
    echo 'Must be run as root!'
    exit 1
  fi

# Create backups
  for file in ${SYSFILES[*]}; do
    backup_file $file
  done

# Verify that there exists a user named 'hadoop'
  echo -n '* Verifying user hadoop exists'
  id hadoop > /dev/null
  if [[ $? -ne '0' ]]; then
    echo 'Hadoop user does not exist.'
    echo 'Creating hadoop user'
    # create the hadoop user if it doesn't exist
    useradd -m hadoop
    passwd hadoop
    print_ok
  else
    echo
  fi

  echo '* Applying changes'
# Turn off SELinux
  apply_subst 'SELINUX=\(enforcing\|permissive\)' 'SELINUX=disabled' $SELINUX_DIR/config 'Turning off SELinux'
# Turn off some SSHD services to speed up SSH
  apply_subst '^\(GSSAPI[a-zA-Z]\+\) yes' '\1 no' $SSHD_DIR/sshd_config 'Turning off GSSAPI for SSHD' 
# Turn off StrictHostKeyChecking in ssh config
  apply_subst 'StrictHostKeyChecking yes' 'StrictHostKeyChecking no' $SSHD_DIR/ssh_config

# Network stuff, read everything if you want to know what it's doing
  add_line 'net.ipv6.conf.all.disable_ipv6=1' /etc/sysctl.conf
  add_line 'net.ipv6.default.disable_ipv6=1' /etc/sysctl.conf
  add_line 'net.core.somaxconn=1024' /etc/sysctl.conf

# Add the gateway address of the network
  add_line 'NETWORKING=yes' /etc/sysconfig/network
  add_line 'GATEWAY=192.168.1.1' /etc/sysconfig/network

# Add lines to resolv.conf
  add_line 'search appstate.edu' /etc/resolv.conf
  add_line 'nameserver 152.10.2.222' /etc/resolv.conf
  add_line 'nameserver 152.10.2.223' /etc/resolv.conf

# Increase the maximum number of file handles per user
  add_line 'hadoop	hard nofile		65536' /etc/security/limits.conf
  add_line 'hadoop	soft nofile		65536' /etc/security/limits.conf
  add_line 'hadoop	hard nproc		65536' /etc/security/limits.conf
  add_line 'hadoop	soft nproc		65536' /etc/security/limits.conf

# Turn on noatime writing, so when files are read they aren't written to. This is done by modifying the fstab.
  get_yesno 'Are you using the default partitioning scheme provided by CentOS? [y/n] ' part
  if [[ "$part" = "y" ]]; then
    apply_subst "\(\/dev\/mapper\/centos-[a-z]\+ \/[a-z]*[\t ]\+[a-z]\+[\t ]\+\)defaults" "\1defaults,noatime" /etc/fstab 'Applying fstab changes'
  else
    echo 'You have indicated that you are not using the default partitioning scheme. This is okay, but you should'
    echo 'manually edit your /etc/fstab file so that the flags on the partitions you access for hadoop read "default,noatime"'
    echo 'If you meant to enter "y", you may run this install script again.'
  fi

  if [[ -z ~/.ssh/id_rsa.pub ]]; then
    echo '* Generating SSH key'
    ssh-keygen
    echo '* Logging into the namenode and adding our public key'
    # This line will append this node's public key to the name node's authorized_keys file, and vice versa.
    cat ~/.ssh/id_rsa.pub | ssh $NAMENODE 'cat >> ~/.ssh/authorized_keys; cat ~/.ssh/id_rsa.pub' >> ~/.ssh/authorized_keys
  fi

# Confirm that we're connected to the internet by pinging google
  echo '* Installing hadoop'
  ping google.com -c 1 > /dev/null
  if [[ $? -ne 0 ]]; then
    print_skip
  else
    # I'm aware that it says "centos6" but it doesn't matter
    wget -O /etc/yum.repos.d/bigtop.repo http://www.apache.org/dist/bigtop/stable/repos/centos6/bigtop.repo
    # update repolist, then install hadoop
    yum update -y
    yum install hadoop\* -y
  fi

# Create patches
  echo '* Creating patches for rollback'
  mkdir ${PATCH_DIR} -p
  for path in ${SYSFILES[*]}; do
    # Go through each of the backups and do a diff with the new version
    file=$(basename "$path")
    backup_file=$BACKUP_DIR/$file
    patch_file="$PATCH_DIR/$file".patch

    status="Creating patch for $file..."
    echo -n $status
    if [[ -e $patch_file ]]; then
      # patch already exists, so don't overwrite it with an empty patch
      print_skip
    else
      diff $path $backup_file > $patch_file
      print_ok
    fi
  done
}

function uninstall {
# Replace all of the backups to their original location
  echo 'uninstalling'
}

# run here
if [[ $# -eq 0 ]]; then
  echo "usage: $0 [ install | uninstall ]"
  exit 0
else
  case $1 in
    install|uninstall)
# run either install or uninstall, whichever one it was
    $1
    ;;

    *)
    echo "usage: $0 [ install | uninstall ]"
    exit 0
    ;;
  esac
fi

