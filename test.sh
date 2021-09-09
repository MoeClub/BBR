#!/bin/bash
# By MoeClub

installDep=()
for dep in $(echo "gcc,make" |sed 's/,/\n/g'); do command -v "${dep}" >/dev/null || installDep+=("${dep}"); done
ls -1 "/usr/src" |grep -q "^linux-headers-$(uname -r)" || installDep+=("linux-headers-$(uname -r)")

if [ "${#installDep[@]}" -gt 0 ]; then
  apt update
  apt install -y "${installDep[@]}"
  if [ $? -ne 0 ]; then
    echo "Install Package Fail."
    exit 1
  fi
fi

kernelVer=$(uname -r |cut -d- -f1 |cut -d. -f1-2)
[ ! -n "${kernelVer}" ] && echo "No Found Kernel Version." && exit 1

wget -qO /tmp/tcp_bbr.c "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/net/ipv4/tcp_bbr.c?h=v${kernelVer}"
[ $? -ne 0 ] && echo "Invalid Kernel Version." && exit 1

wget -qO /tmp/Makefile "https://github.com/MoeClub/BBR/raw/master/Makefile"
[ $? -ne 0 ] && echo "Invalid Make File." && exit 1




cd /tmp
make && make install



