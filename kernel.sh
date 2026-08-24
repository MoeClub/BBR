#!/usr/bin/env sh

cloud="${1:-1}"

if command -v apt >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  images="linux-image-amd64"
  headers="linux-headers-amd64"
  [ "$cloud" != "0" ] && images="linux-image-cloud-amd64" && headers="linux-headers-cloud-amd64"

  apt -qqy update
  apt list --installed 2>/dev/null |grep '^linux-image-\|^linux-headers-' |cut -d'/' -f1 |xargs apt remove --purge -y
  apt install -y "${images}" "${headers}"
  [ "$?" -eq "0" ] && reboot

elif command -v apk >/dev/null 2>&1; then
  images="linux-lts"
  headers="linux-lts-dev"
  [ "$cloud" != "0" ] && images="linux-virt" && headers="linux-virt-dev"

  apk update
  apk info |grep '^linux-\(lts\|virt\)\(-dev\)\?$' |xargs apk del 
  apk add --no-cache "${images}" "${headers}"
  [ "$?" -eq "0" ] && reboot

fi
