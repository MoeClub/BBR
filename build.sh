#!/bin/bash
# By MoeClub

[ "$1" != "-f" ] && [ ! -f "/lib/modules/$(uname -r)/kernel/net/ipv4/tcp_bbr.ko" ] && echo "This Kernel Not Support BBR by Default." && exit 1

installDep=()
for dep in $(echo "gcc,make,openssl,keyutils" |sed 's/,/\n/g'); do command -v "${dep}" >/dev/null || installDep+=("${dep}"); done
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

downloadOK=0
[ "$downloadOK" == "0" ] && wget --no-check-certificate --timeout=10 -qO /tmp/tcp_bbr.c "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/net/ipv4/tcp_bbr.c?h=v${kernelVer}"
[ $? -eq 0 ] && downloadOK=1
[ "$downloadOK" == "0" ] && wget --no-check-certificate --timeout=10 -qO /tmp/tcp_bbr.c "https://raw.githubusercontent.com/torvalds/linux/refs/tags/v${kernelVer}/net/ipv4/tcp_bbr.c"
[ $? -eq 0 ] && downloadOK=1
[ "$downloadOK" -ne "1" ] && echo "Invalid Kernel Version." && exit 1

# bbr_min_rtt_win_sec
sed -i 's|static const u32 bbr_min_rtt_win_sec[^;]*;|static const u32 bbr_min_rtt_win_sec = 13;|g' /tmp/tcp_bbr.c

# bbr_probe_rtt_mode_ms
sed -i 's|static const u32 bbr_probe_rtt_mode_ms[^;]*;|static const u32 bbr_probe_rtt_mode_ms = 56;|g' /tmp/tcp_bbr.c

# bbr_min_tso_rate
sed -i 's|static const int bbr_min_tso_rate[^;]*;|static const int bbr_min_tso_rate = 256000;|g' /tmp/tcp_bbr.c

# bbr_gain
sed -i 's|static const int bbr_high_gain[^;]*;|static const int bbr_high_gain = BBR_UNIT * (2885 * 2) / 1000 + 1;|g' /tmp/tcp_bbr.c
sed -i 's|static const int bbr_drain_gain[^;]*;|static const int bbr_drain_gain = BBR_UNIT * 2 * 1000 / 2885;|g' /tmp/tcp_bbr.c

# bbr_pacing_gain
sed -i '1h;1!H;$!d;${g;s|static const int bbr_pacing_gain\[\][^;]*;|static const int bbr_pacing_gain[] = \{\n        BBR_UNIT * 16 / 8,\n        BBR_UNIT * 6 / 8,\n        BBR_UNIT * 16 / 8,        BBR_UNIT * 10 / 8,        BBR_UNIT * 14 / 8,\n        BBR_UNIT * 10 / 8,        BBR_UNIT * 12 / 8,        BBR_UNIT * 10 / 8\n\};|g;}' /tmp/tcp_bbr.c

# bbr_full_bw_thresh
sed -i 's|static const u32 bbr_full_bw_thresh[^;]*;|static const u32 bbr_full_bw_thresh = BBR_UNIT * 17 / 16;|g' /tmp/tcp_bbr.c

# bbr_lt_bw
sed -i 's|static const u32 bbr_lt_bw_ratio[^;]*;|static const u32 bbr_lt_bw_ratio = BBR_UNIT / 4;|g' /tmp/tcp_bbr.c
sed -i 's|static const u32 bbr_lt_bw_diff[^;]*;|static const u32 bbr_lt_bw_diff = 8000 / 8;|g' /tmp/tcp_bbr.c

# mark
sed -i 's|^MODULE_DESCRIPTION([^;]*;|MODULE_DESCRIPTION("TCP BBR (Bottleneck Bandwidth and RTT) [SV: '$(date +%Y/%m/%d)' Installed]");|g' /tmp/tcp_bbr.c


# makefile
cat >/tmp/Makefile<<EOF
obj-m := tcp_bbr.o

all:
	make -C /lib/modules/\`uname -r\`/build M=\`pwd\` modules CC=\`which gcc\`
	
clean:
	make -C /lib/modules/\`uname -r\`/build M=\`pwd\` clean

sysctlDel:
	sed -i '/net\.core\.default_qdisc/d' /etc/sysctl.conf
	sed -i '/net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
	while [ -z "\$\$(sed -n '\$\$p' /etc/sysctl.conf)" ]; do sed -i '\$\$d' /etc/sysctl.conf; done

sysctlAdd:
	make sysctlDel
	sed -i '\$\$a\net.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr\n\n' /etc/sysctl.conf
	sysctl -p
	
signModule:
	openssl req -new -nodes -utf8 -sha256 -days 36500 -batch -x509 -subj '/C=/ST=/L=/OU=/O=/CN=Module.TCP_BBR' -rand /dev/urandom -outform PEM -keyout /tmp/kernel.key.pem -out /tmp/kernel.crt.pem >/dev/null 2>&1
	#keyctl padd asymmetric 'Module.TCP_BBR' 0x\`cat /proc/keys |grep '.builtin_trusted_keys' |cut -d' ' -f1\` < /tmp/kernel.key.pem
	keyctl padd user 'Module.TCP_BBR' @u < /tmp/kernel.crt.pem
	/usr/src/linux-headers-\`uname -r\`/scripts/sign-file \`cat /boot/config-$(uname -r) |grep -v '^#' |grep '^CONFIG_MODULE_SIG_HASH' |cut -d'"' -f2\` /tmp/kernel.key.pem /tmp/kernel.crt.pem tcp_bbr.ko

install:
	# make signModule
	cp -rf tcp_bbr.ko /lib/modules/\`uname -r\`/kernel/net/ipv4
	insmod /lib/modules/\`uname -r\`/kernel/net/ipv4/tcp_bbr.ko 2>/dev/null || true
	depmod -a
	make sysctlAdd

uninstall:
	rm -rf /lib/modules/\`uname -r\`/kernel/net/ipv4/tcp_bbr.ko
	make sysctlDel

EOF

cd /tmp
make && make install
