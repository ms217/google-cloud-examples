#!/bin/bash
#A very brief example of autoscaling GCE webservices that shall serve a plain html website
#Requires a few attributes to be set under metadata in GCE
#Environment: CentOS 7.xx with EPEL
#This Script should be easily adaptable to other distros though...


if [ -f /root/.startup_initial ]
then
	ini_val=$(head -n1 /root/.startup_initial)
		if [ $ini_val == 1 ]
		then
			echo "/root/.startup_initial with value 1 found!"
			exit 1
		fi
fi



git_repo=https://raw.githubusercontent.com/ms217/google-cloud-examples/master/bash/lb-autoscaling/
gluster_release=centos-release-gluster41.noarch
pure_ftpd_conf=/etc/pure-ftpd/pure-ftpd.conf
sshd_conf=/etc/ssh/sshd_config

yum update -y
yum install -y nginx net-tools bind-utils nmap tcpdump curl wget lynx iftop atop iotop ntp ntpdate ntp-doc pure-ftpd $gluster_release\
 mlocate jwhois telnet ftp htop siege lsof strace rsync httpry goaccess nload
yum install -y glusterfs-server glusterfs-coreutils 
updatedb


#set the timezone - use "timedatectl list-timezones" to get a list of available TZs...
timezone=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/timezone" -H "Metadata-Flavor: Google")
timedatectl set-timezone $timezone

#For testing purposes we deactivate selinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config


#create a swap file of X percent of the total free space of /
percent_swap=10
dsk_space_avail=$(df --output=avail / | sed '1d;s/[^0-9]//g')
swap_size=$(awk "BEGIN { pc=${percent_swap}*${dsk_space_avail}/100; i=int(pc); print (pc-i<0.5)?i:i+1 }")
fallocate -l $swap_size"K" /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
swapon -s
echo "/swapfile none swap sw 0 0" >> /etc/fstab




[ -d /etc/sysctl.d ] && wget $git_repo/90-custom_sysctl.conf -O /etc/sysctl.d/90-custom_sysctl.conf && sysctl -p /etc/sysctl.d/90-custom_sysctl.conf
[ -d /etc/nginx ] && wget $git_repo/nginx.conf -O /etc/nginx/nginx.conf
[ -d /etc/nginx/conf.d ] && wget $git_repo/vhost.conf -O /etc/nginx/conf.d/vhost.conf

mkdir -p /var/log/nginx/log

management_ip=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/management_ip" -H "Metadata-Flavor: Google")
vhost_name=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/vhost_name" -H "Metadata-Flavor: Google")
sed -i "s#_MANAGEMENT_IP_#`echo $management_ip`#g" /etc/nginx/nginx.conf
sed -i "s#_VHOST_NAME_#`echo $vhost_name`#g" /etc/nginx/conf.d/vhost.conf

if [ -f $pure_ftpd_conf ]
then
	sed -ri 's/^MaxClientsPerIP(.*)/MaxClientsPerIP             40/g' $pure_ftpd_conf
	sed -ri 's/^MaxClientsNumber(.*)/MaxClientsNumber            50/g' $pure_ftpd_conf
fi

if [ -f $sshd_conf ]
then
	sed -i 's/PermitRootLogin no/#PermitRootLogin no/g' $sshd_conf
	systemctl restart sshd
fi

systemctl enable glusterd
systemctl enable pure-ftpd
systemctl enable nginx
systemctl enable ntpdate
systemctl start glusterd
systemctl start pure-ftpd
systemctl start nginx

mkdir -p /mnt/gluster-storage


ftpuser=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/ftp-user" -H "Metadata-Flavor: Google")
ftppass=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/ftp-passwd" -H "Metadata-Flavor: Google")
useradd $ftpuser -d /mnt/gluster-storage/web -m
echo "$ftppass" | passwd --stdin $ftpuser



#Update Hostname of the default nginx index.html file.
[ -f /usr/share/nginx/html/index.html ] && sed -i "s#on Fedora#on `hostname`#g" /usr/share/nginx/html/index.html

#Todo/Notes:
#determine if the newly spawned instance is the very first instance of this gce project
#keep this information somewhere
#
# for i in $(gcloud compute instances list | grep -v NAME | awk ' { print $1 } '); do gluster peer probe $i ; done
# for i in $(gcloud compute instances list | grep -v NAME | awk ' { print $1 } '); do echo $i ; done
# gluster volume create web $(hostname):/mnt/gluster/web force
#
#from a new gluster node ($new_node), connect to very first instance aka master:
# gcloud -q compute ssh --zone europe-west1-d instance-1 --command "gluster peer probe $new_node"
#
#add via gcloud command and via ssh the new node to the gluster pool on instance-1


echo "1" > /root/.startup_initial


