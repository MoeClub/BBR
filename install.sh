#!/bin/bash

[ "$EUID" -ne '0' ] && echo "Error:This script must be run as root!" && exit 1;

echo "Download: linux-image-4.14.153_4.14.153-1_amd64.deb"
wget --no-check-certificate -qO '/tmp/linux-image-4.14.153_4.14.153-1_amd64.deb' 'https://github.com/MoeClub/BBR/releases/latest/download/linux-image-4.14.153_4.14.153-1_amd64.deb'
dpkg -i '/tmp/linux-image-4.14.153_4.14.153-1_amd64.deb'
[ $? -eq 0 ] || exit 1 

sed -i '/net\.core\.default_qdisc/d' /etc/sysctl.conf
sed -i '/net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
while [ -z "$(sed -n '$p' /etc/sysctl.conf)" ]; do sed -i '$d' /etc/sysctl.conf; done
sed -i '$a\net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n\n' /etc/sysctl.conf

item="linux-image-4.14.153"
while true; do
  List_Kernel="$(dpkg -l |grep 'linux-image\|linux-modules\|linux-generic\|linux-headers' |grep -v "${item}")"
  Num_Kernel="$(echo "$List_Kernel" |sed '/^$/d' |wc -l)"
  [ "$Num_Kernel" -eq "0" ] && break
  for kernel in `echo "$List_Kernel" |awk '{print $2}'`
    do
      if [ -f "/var/lib/dpkg/info/${kernel}.prerm" ]; then
        sed -i 's/linux-check-removal/#linux-check-removal/' "/var/lib/dpkg/info/${kernel}.prerm"
        sed -i 's/uname -r/echo purge/' "/var/lib/dpkg/info/${kernel}.prerm"
      fi
      dpkg --force-depends --purge "$kernel"
    done
  done
apt-get autoremove -y

echo -e "\n\nPlease reboot it...\n"
