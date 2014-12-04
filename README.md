hadoop-postinstall
=
Hadoop postinstall is a bash script that will perform various post installation steps on a CentOS 7-minimal machine to ready it for being a Hadoop cluster.

Actions performed include:
* Adding the hadoop user
* Turning off SELinux
* Turning off SSHD services to speed up SSH
* Turning off IPv6 services
* Static IP configuration
* Increasing max number of open file handles for the hadoop user
* Turning on the noatime flag on filesystems
* Automated installation of necessary programs (wget, java, hadoop, et al.)

All system files that are modified are backed up and have patches generated for them.

Known issues
=
* /etc/hosts file will write the list of hosts each time, and not detect that the lines are in there, resulting in staggeringly large /etc/host files if you run this script a bunch of times
* More to come...

License
=
BSD 3-clause license
