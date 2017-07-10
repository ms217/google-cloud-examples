#!/bin/bash
#A very brief example of autoscaling webservices that'll serve a plain html website
#Requires a few attributes to be set under metadata in GCE

yum update -y
yum install -y nginx net-tools bind-utils nmap tcpdump curl lynx iftop atop ntp ntpdate ntp-doc pure-ftpd centos-release-gluster310.noarch mlocate jwhois telnet ftp htop siege
yum install -y glusterfs-server glusterfs-coreutils 
updatedb


timezone=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/timezone" -H "Metadata-Flavor: Google")
timedatectl set-timezone $timezone

systemctl enable glusterd
systemctl enable pure-ftpd
systemctl enable nginx
systemctl enable ntpdate
systemctl start glusterd
systemctl start pure-ftpd
systemctl start nginx

mkdir -p /mnt/gluster


ftpuser=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/ftp-user" -H "Metadata-Flavor: Google")
useradd $ftpuser -d /mnt/gluster-storage/web -M




[ -f /usr/share/nginx/html/index.html ] && sed -i "s#on Fedora#on `hostname`#g" /usr/share/nginx/html/index.html
