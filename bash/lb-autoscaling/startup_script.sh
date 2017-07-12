#!/bin/bash
#A very brief example of autoscaling GCE webservices that shall serve a plain html website
#Requires a few attributes to be set under metadata in GCE
#Environment: CentOS 7.xx with EPEL
#This Script should be easily adaptable to other distros though...


git_repo=https://raw.githubusercontent.com/ms217/google-cloud-examples/master/bash/lb-autoscaling/

yum update -y
yum install -y nginx net-tools bind-utils nmap tcpdump curl wget lynx iftop atop ntp ntpdate ntp-doc pure-ftpd centos-release-gluster310.noarch mlocate jwhois telnet ftp htop siege
yum install -y glusterfs-server glusterfs-coreutils 
updatedb


#set the timezone - use "timedatectl list-timezones" to get a list of available TZs...
timezone=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/timezone" -H "Metadata-Flavor: Google")
timedatectl set-timezone $timezone

#For testing purposes we deactivate selinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

[ -d /etc/sysctl.d ] && wget $git_repo/90-custom_sysctl.conf -O /etc/sysctl.d/90-custom_sysctl.conf && sysctl -p
[ -d /etc/nginx ] && wget $git_repo/nginx.conf -O /etc/nginx/nginx.conf && wget $git_repo/vhost.conf -O /etc/nginx/conf.d/vhost.conf


management_ip=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/management_ip" -H "Metadata-Flavor: Google")
vhost_name=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/vhost_name" -H "Metadata-Flavor: Google")
sed -i "s#<MANAGEMENT_IP>#`$management_ip`#" /etc/nginx/nginx.conf
sed -i "s#<VHOST_NAME>#`$vhost_name`#" /etc/nginx/conf.d/vhost.conf


systemctl enable glusterd
systemctl enable pure-ftpd
systemctl enable nginx
systemctl enable ntpdate
systemctl start glusterd
systemctl start pure-ftpd
systemctl start nginx

mkdir -p /mnt/gluster


ftpuser=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/ftp-user" -H "Metadata-Flavor: Google")
ftppass=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/ftp-passwd" -H "Metadata-Flavor: Google")
useradd $ftpuser -d /mnt/gluster-storage/web -M
echo "$ftppass" | passwd --stdin $ftpuser



#Update Hostname of the default nginx index.html file.
[ -f /usr/share/nginx/html/index.html ] && sed -i "s#on Fedora#on `hostname`#g" /usr/share/nginx/html/index.html



