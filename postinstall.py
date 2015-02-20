#!/usr/bin/env python2
import os, sys, shutil
import re
from os.path import *
import pwd, grp


########################################################################################################
# Utility functions 
########################################################################################################
def add_line(path, line):
  """
  Adds a line to a file, if it doesn't already exist in the file.
  """
  with open(path, 'a+') as fp:
    contents = fp.read().split('\n')
    print "Appending", line, "to", path, '...',
    if line not in contents:
      # append the line if it doesn't exist in the contents
      fp.write(line + "\n")
      print 'OK'
    else:
      print 'SKIP'


def apply_subst(path, pattern, replace):
  """
  Applies a substitution to a given path
  """
  with open(path, 'w+') as fp:
    contents = fp.read()
    print 'Applying substitution to', path, '...',
    if not re.search(pattern, contents):
      print "SKIP (pattern not found)"
    else:
      contents = re.sub(pattern, replace, contents)
      fp.write(contents)
      print 'OK'


def system(command, exit_on_fail=True, fail_msg=None):
  """
  Sends a command line to be processed by the shell. Exits on unsuccessful execution by default.
  """
  result = os.system(command)
  if result != 0:
    fail_msg = "System command \"" + command + "\" failed."
    if exit_on_fail: fail_quit(fail_msg)
    else: fail(fail_msg)


def fail(message):
  """
  Prints an error message to the screen, and continues
  """
  print "Error:",message


def fail_quit(message):
  """
  Prints an error message to the screen, and exits
  """
  fail(message)
  print "ABORTING"
  sys.exit(1)

########################################################################################################
# Constants for adding
########################################################################################################
BASH_PROFILE_LINES = [
  "export JAVA_HOME=/etc/alternatives/jre",
  "export HADOOP_PREFIX=$HOME/hadoop",
  "export HADOOP_CONF_DIR=$HADOOP_PREFIX/etc/hadoop/conf",
  "export PATH=\"$PATH:$HADOOP_PREFIX/sbin:$HADOOP_PREFIX/bin\""
]

HADOOP_HOME="/home/hadoop"
HADOOP_MIRROR="http://mirror.metrocast.net/apache/hadoop/common/hadoop-2.5.2/hadoop-2.5.2.tar.gz"

########################################################################################################
# Install function
########################################################################################################
def install():
  # check if user is superuser
  if(os.geteuid() != 0):
    print 'Must be run as root!'
    return False

  # backups

  # verify that a hadoop user exists
  print '* Verifying user hadoop exists'
  users = [u.pw_name for u in pwd.getpwall()]
  if 'hadoop' not in users:
    print '* Creating hadoop user'
    result = system('useradd -m hadoop', fail_msg="failed to create hadoop user")
    if result != 0:
      fail_quit("failed to create hadoop user")
    print '* Setting hadoop user password'
    system("passwd hadoop", False, "failed to set hadoop user password. be sure to set it by using the passwd command after running this script.")
  
  # Get whether hadoop account is in wheel
  print "* Verifying hadoop user is in group wheel"
  try:
    members = grp.getgrpnam("wheel")
    if 'hadoop' not in members:
      system("usermod -a -G wheel hadoop", False)
  except:
    system("usermod -a -G wheel hadoop", False)

  # Add lines to bashrc and bash_profile
  for line in BASH_PROFILE_LINES:
    add_line(join(HADOOP_HOME, '.bashrc'), line)
    add_line(join(HADOOP_HOME, '.bash_profile'), line)

  print '* Applying changes'
  # Apply misc changes
  # Disable SELinux
  apply_subst("/etc/selinux/config", r"(SELINUX=(enforcing|permissive))?", r"SELINUX=disabled")
  # Turn off SSHD services
  apply_subst("/etc/ssh/sshd_config", r"^(GSSAPI[a-zA-Z]+) yes", r"\1 no")
  add_line("/etc/ssh/ssh_config", "StrictHostKeyChecking no")
  # Network stuff
  add_line("/etc/sysctl.conf", "net.ipv6.conf.all.disable_ipv6=1")
  add_line("/etc/sysctl.conf", "net.ipv6.default.disable_ipv6=1")
  add_line("/etc/sysctl.conf", "net.core.somaxconn=1024")
  add_line("/etc/sysconfig/network", "NETWORKING=yes")
  add_line("/etc/sysconfig/network", "GATEWAY=192.168.1.1")
  add_line("/etc/resolv.conf", "search appstate.edu")
  add_line("/etc/resolv.conf", "nameserver 152.10.2.222")
  add_line("/etc/resolv.conf", "nameserver 152.10.2.223")
  add_line("/etc/security/limits.conf", 'hadoop\thard\tnofile\t\t65536')
  add_line("/etc/security/limits.conf", 'hadoop\tsoft\tnofile\t\t65536')
  add_line("/etc/security/limits.conf", 'hadoop\thard\tnproc\t\t65536')
  add_line("/etc/security/limits.conf", 'hadoop\tsort\tnproc\t\t65536')
  # Filesystem noatime flags
#  apply_subst("/etc/fstab", 
#    r"\(\/dev\/mapper\/centos-[a-z]\+ \/[a-z]*[\t ]\+[a-z]\+[\t ]\+\)defaults", r"\1defaults,noatime")
  
  # Run some system commands
  if not exists(join(HADOOP_HOME, ".ssh", "id_rsa.pub")):
    print '* Generating SSH key'
    system("su hadoop -c 'ssh-keygen'", fail_msg="could not generate SSH key")

  print '* Installing hadoop, java'
  # Confirm that we're connected to the internet by pinging google.com
  system("ping google.com -c 1", fail_msg="not connected to the internet, make sure you are connected!")
  system("yum install java-1.7.0-openjdk-devel wget -y", fail_msg="could not install Java and wget")
  
  if exists(join(HADOOP_HOME, "hadoop")):
    print 'Hadoop is already installed, skipping'
  else:
    system("wget " + HADOOP_MIRROR, fail_msg="could not download Hadoop. Change the Hadoop script to download from a different mirror.")
    system("tar xf hadoop-2.5.2.tar.gz")
    os.rename("hadoop-2.5.2", join(HADOOP_HOME, "hadoop"))
    os.remove("hadoop-2.5.2.tar.gz")
    system("chown hadoop " + join(HADOOP_HOME, "hadoop"))
  
  # TODO : add hosts to /etc/hosts

if __name__ == "__main__":
	install()
