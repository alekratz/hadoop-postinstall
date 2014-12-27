hadoop-postinstall
=
Hadoop postinstall is a bash script that will perform various post installation steps on a CentOS 7-minimal machine to ready it for being a Hadoop cluster.

Actions performed include:
* Adding the hadoop user
* Optimizing the OS for Hadoop by turning on and off certain services
* Automated installation of necessary programs (wget, java, hadoop, et al.)

There are two other scripts, involved in setting up a simple cluster with a dual NIC machine acting as a router on a switch with many single NIC machines. These will set up the network for the appropriate machines.

All system files that are modified are backed up and have patches generated for them.

Known issues
=
* postinstall.sh will infinitely add lines to /etc/security/limits.conf
* More to come...

License
=
BSD 3-clause license
