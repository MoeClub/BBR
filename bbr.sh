#!/usr/bin/env sh
# BBR By MoeClub

kernelVer="$(uname -r |cut -d- -f1 |cut -d. -f1-2)"
[ ! -n "${kernelVer}" ] && echo "Not Found Kernel Version." && exit 1


instDep=""
command -v apt >/dev/null 2>&1 && buildDep="wget:wget gcc:gcc make:make sed:sed modprobe:kmod" && { [ -d "/lib/modules/$(uname -r)/build" ] || instDep="linux-headers-$(uname -r) ${instDep}"; }
command -v apk >/dev/null 2>&1 && buildDep="wget:wget gcc:gcc make:make sed:sed modprobe:kmod" && { [ -d "/lib/modules/$(uname -r)/build" ] || { kernelName="$(uname -r)" && kernelRel="${kernelName%-*}" && instDep="linux-${kernelName##*-}-dev=${kernelRel%-*}-r${kernelRel##*-} ${instDep}"; }; }
for dep in ${buildDep}; do command -v "${dep%%:*}" >/dev/null || instDep="${dep##*:} ${instDep}"; done


if [ -n "${instDep%% }" ]; then
  ret="1"
  [ "$ret" -ne 0 ] && command -v apt >/dev/null 2>&1 && { export DEBIAN_FRONTEND=noninteractive && apt -qq update && apt -qqy install --no-install-recommends ${instDep%% }; ret="$?"; }
  [ "$ret" -ne 0 ] && command -v apk >/dev/null 2>&1 && { apk update && apk add --no-cache ${instDep%% }; ret="$?"; }
  [ "$ret" -ne 0 ] && echo "Install Package Fail." && exit 1
fi


[ -f "/tmp/tcp_bbr.c-manual" ] && mv "/tmp/tcp_bbr.c-manual" "/tmp/tcp_bbr.c" && downloadOK=1 || downloadOK=0
[ "$downloadOK" -eq 0 ] && wget --no-check-certificate --timeout=10 -qO /tmp/tcp_bbr.c "https://raw.githubusercontent.com/torvalds/linux/refs/tags/v${kernelVer}/net/ipv4/tcp_bbr.c"
[ $? -eq 0 ] && downloadOK=1
[ "$downloadOK" -eq 0 ] && wget --no-check-certificate --timeout=10 -qO /tmp/tcp_bbr.c "https://gitlab.com/linux-kernel/linux/-/raw/v${kernelVer}/net/ipv4/tcp_bbr.c"
[ $? -eq 0 ] && downloadOK=1
[ "$downloadOK" -eq 0 ] && wget --no-check-certificate --timeout=10 -qO /tmp/tcp_bbr.c "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/net/ipv4/tcp_bbr.c?h=v${kernelVer}"
[ $? -eq 0 ] && downloadOK=1
[ "$downloadOK" -ne 1 ] && echo "Invalid Kernel Version." && exit 1



# bbr_bw_rtts
sed -i 's|static const int bbr_bw_rtts[^;]*;|static const int bbr_bw_rtts = 11;|g' /tmp/tcp_bbr.c


# bbr_min_rtt_win_sec
sed -i 's|static const u32 bbr_min_rtt_win_sec[^;]*;|static const u32 bbr_min_rtt_win_sec = 13;|g' /tmp/tcp_bbr.c


# bbr_probe_rtt_mode_ms
sed -i 's|static const u32 bbr_probe_rtt_mode_ms[^;]*;|static const u32 bbr_probe_rtt_mode_ms = 26;|g' /tmp/tcp_bbr.c


# bbr_pacing_margin_percent
sed -i 's|static const int bbr_pacing_margin_percent[^;]*;|static const int bbr_pacing_margin_percent = 1;|g' /tmp/tcp_bbr.c


# bbr_pacing_gain
sed -i '1h;1!H;$!d;${g;s|static const int bbr_pacing_gain\[\][^;]*;|static const int bbr_pacing_gain[] = \{\n        BBR_UNIT * 6 / 8,\n        BBR_UNIT * 11 / 8,\n        BBR_UNIT * 7 / 8,        BBR_UNIT * 9 / 8,        BBR_UNIT * 7 / 8,\n        BBR_UNIT * 10 / 8,        BBR_UNIT * 7 / 8,        BBR_UNIT * 9 / 8\n\};|g;}' /tmp/tcp_bbr.c


# bbr_cycle_rand
sed -i 's|static const u32 bbr_cycle_rand[^;]*;|static const u32 bbr_cycle_rand = 7;|g' /tmp/tcp_bbr.c


# bbr_full_bw_thresh
sed -i 's|static const u32 bbr_full_bw_thresh[^;]*;|static const u32 bbr_full_bw_thresh = BBR_UNIT * 18 / 16;|g' /tmp/tcp_bbr.c


# bbr_lt_bw
sed -i 's|static const u32 bbr_lt_loss_thresh[^;]*;|static const u32 bbr_lt_loss_thresh = 128;|g' /tmp/tcp_bbr.c
sed -i 's|static const u32 bbr_lt_bw_ratio[^;]*;|static const u32 bbr_lt_bw_ratio = BBR_UNIT / 16;|g' /tmp/tcp_bbr.c
sed -i 's|static const u32 bbr_lt_bw_diff[^;]*;|static const u32 bbr_lt_bw_diff = 4000 / 8;|g' /tmp/tcp_bbr.c
sed -i 's|static const u32 bbr_lt_bw_max_rtts[^;]*;|static const u32 bbr_lt_bw_max_rtts = 4;|g' /tmp/tcp_bbr.c


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

sysctlAdd:
	make sysctlDel
	sed -i '\$\$a\net.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr\n\n' /etc/sysctl.conf
	sysctl -p 2>/dev/null

install:
	mkdir -p /lib/modules/\`uname -r\`/updates
	cp -rf tcp_bbr.ko /lib/modules/\`uname -r\`/updates
	depmod -a
	insmod /lib/modules/\`uname -r\`/updates/tcp_bbr.ko 2>/dev/null || true
	make sysctlAdd
	modinfo tcp_bbr 2>/dev/null || true

uninstall:
	rm -rf /lib/modules/\`uname -r\`/updates/tcp_bbr.ko
	make sysctlDel

EOF

cd /tmp
make && make install
