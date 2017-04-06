#!/bin/sh /etc/rc.common
#
# Copyright (C) 2014 Justin Liu <rssnsj@gmail.com>
# https://github.com/rssnsj/network-feeds
#

START=99

#
# Data source of /etc/gfwlist/china-banned:
#  https://github.com/zhiyi7/ddwrt/blob/master/jffs/vpn/dnsmasq-gfw.txt
#  http://code.google.com/p/autoproxy-gfwlist/
#

SS_REDIR_PORT=7070
SS_TUNNEL_PORT=7071
SS_REDIR_PIDFILE=/var/run/ssr-redir-go.pid 
SS_TUNNEL_PIDFILE=/var/run/ssr-tunnel-go.pid 
PDNSD_LOCAL_PORT=5053 #alex:防止和单独的pdnsd服务冲突
SSR_CONF=/etc/shadowsocksr.json
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

# New implementation:
# Attach rules to main 'dnsmasq' service and restart it.

__gfwlist_by_mode()
{
	case "$1" in
		V) echo unblock-youku;;
		*) echo china-banned;;
	esac
}

start()
{
	local vt_enabled=`uci get shadowsocksr.@shadowsocksr[0].enabled 2>/dev/null`
	local vt_server_addr=`uci get shadowsocksr.@shadowsocksr[0].server`
	local vt_server_port=`uci get shadowsocksr.@shadowsocksr[0].server_port`
	local vt_password=`uci get shadowsocksr.@shadowsocksr[0].password 2>/dev/null`
	local vt_method=`uci get shadowsocksr.@shadowsocksr[0].method`
	local vt_protocol=`uci get shadowsocksr.@shadowsocksr[0].protocol`
	local vt_obfs=`uci get shadowsocksr.@shadowsocksr[0].obfs`
	local vt_obfs_param=`uci get shadowsocksr.@shadowsocksr[0].obfs_param`
	local vt_protocol_param=`uci get shadowsocksr.@shadowsocksr[0].protocol_param`
	local vt_timeout=`uci get shadowsocksr.@shadowsocksr[0].timeout 2>/dev/null`
	local vt_safe_dns=`uci get shadowsocksr.@shadowsocksr[0].safe_dns 2>/dev/null`
	local vt_safe_dns_port=`uci get shadowsocksr.@shadowsocksr[0].safe_dns_port 2>/dev/null`
	local vt_proxy_mode=`uci get shadowsocksr.@shadowsocksr[0].proxy_mode`
	local vt_dns_mode=`uci get shadowsocksr.@shadowsocksr[0].dns_mode`
	local adbyby=`uci get shadowsocksr.@shadowsocksr[0].adbyby`
	# $covered_subnets, $local_addresses are not required
	local covered_subnets=`uci get shadowsocksr.@shadowsocksr[0].covered_subnets 2>/dev/null`
	local local_addresses=`uci get shadowsocksr.@shadowsocksr[0].local_addresses 2>/dev/null`

	

	# -----------------------------------------------------------------
	if [ "$vt_enabled" = 0 ]; then
		echo "WARNING: Shadowsocksr is disabled."
		return 1
	fi

	if [ -z "$vt_server_addr" -o -z "$vt_server_port" ]; then
		echo "WARNING: Shadowsocksr not fully configured, not starting."
		return 1
	fi

	[ -z "$vt_proxy_mode" ] && vt_proxy_mode=S
	[ -z "$vt_dns_mode" ] && vt_dns_mode=tcp_gfwlist
	[ -z "$vt_method" ] && vt_method=table
	[ -z "$vt_timeout" ] && vt_timeout=60
	case "$vt_proxy_mode" in
		M|S|G|GAME)
			[ -z "$vt_safe_dns" ] && vt_safe_dns="208.67.222.222"
			;;
	esac
	[ -z "$vt_safe_dns_port" ] && vt_safe_dns_port=443
	# Get LAN settings as default parameters
	[ -f /lib/functions/network.sh ] && . /lib/functions/network.sh
	[ -z "$covered_subnets" ] && network_get_subnet covered_subnets lan
	[ -z "$local_addresses" ] && network_get_ipaddr local_addresses lan
	local vt_gfwlist=`__gfwlist_by_mode $vt_proxy_mode`
	vt_np_ipset="china"  # Must be global variable

	# -----------------------------------------------------------------
	###### shadowsocksr ######
cat > $SSR_CONF <<EOF
{
	"server": "$vt_server_addr",
	"server_port": $vt_server_port,
	"local_address": "0.0.0.0",
	"local_port": $SS_REDIR_PORT,
	"password": "$vt_password",
	"method": "$vt_method",
	"timeout": "$vt_timeout",
	"protocol": "$vt_protocol",
	"protocol_param": "$vt_protocol_param",
	"obfs": "$vt_obfs",
	"obfs_param": "$vt_obfs_param",
	"fast_open": false
}
EOF

	sleep 1
	/usr/bin/ssr-redir -c $SSR_CONF -u -b0.0.0.0 -l$SS_REDIR_PORT -s$vt_server_addr -p$vt_server_port \
		-k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_REDIR_PIDFILE || return 1

	# IPv4 firewall rules
	iptables -t nat -N shadowsocksr_pre
	iptables -t nat -F shadowsocksr_pre
	iptables -t mangle -N SSRUDP
	iptables -t mangle -F SSRUDP
	iptables -t nat -A shadowsocksr_pre -m set --match-set local dst -j RETURN || {
		iptables -t nat -A shadowsocksr_pre -d 10.0.0.0/8 -j RETURN
		iptables -t nat -A shadowsocksr_pre -d 127.0.0.0/8 -j RETURN
		iptables -t nat -A shadowsocksr_pre -d 172.16.0.0/12 -j RETURN
		iptables -t nat -A shadowsocksr_pre -d 192.168.0.0/16 -j RETURN
		iptables -t nat -A shadowsocksr_pre -d 127.0.0.0/8 -j RETURN
		iptables -t nat -A shadowsocksr_pre -d 224.0.0.0/3 -j RETURN
	}
	

	iptables -t mangle -A SSRUDP -m set --match-set local dst -j RETURN || {
		iptables -t mangle -A SSRUDP -d 10.0.0.0/8 -j RETURN
		iptables -t mangle -A SSRUDP  -d 127.0.0.0/8 -j RETURN
		iptables -t mangle -A SSRUDP  -d 172.16.0.0/12 -j RETURN
		iptables -t mangle -A SSRUDP  -d 192.168.0.0/16 -j RETURN
		iptables -t mangle -A SSRUDP  -d 127.0.0.0/8 -j RETURN
		iptables -t mangle -A SSRUDP  -d 224.0.0.0/3 -j RETURN
	}

	iptables -t nat -A shadowsocksr_pre -d $vt_server_addr -j RETURN
	iptables -t mangle -A SSRUDP -d $vt_server_addr -j RETURN

	COUNTER=0 #添加内网访问控制
	while true
	do	
		local host=`uci get gfwlist.@lan_hosts[$COUNTER].host 2>/dev/null`
		local lan_enable=`uci get gfwlist.@lan_hosts[$COUNTER].enable 2>/dev/null`
		local mType=`uci get gfwlist.@lan_hosts[$COUNTER].type 2>/dev/null`

		if [ -z "$host" ] || [ -z "$mType" ]; then
			echo $COUNTER ohohoho
			break
		fi
		echo now is $host
		COUNTER=$(($COUNTER+1))
		if [ "$lan_enable" = "0" ]; then
			continue
		fi

		case $mType in
			direct)
				iptables -t nat -A shadowsocksr_pre -s $host -j RETURN
				iptables -t mangle -A SSRUDP -s $host -j RETURN
				;;
			gfwlist)
				mkdir -p /var/etc/dnsmasq-go.d
				ipset create china-banned hash:ip maxelem 65536 2>/dev/null
				iptables -t nat -A shadowsocksr_pre -s $host -m set ! --match-set china-banned dst -j RETURN
				iptables -t nat -A shadowsocksr_pre -s $host -m set --match-set $vt_np_ipset dst -j RETURN
				echo this $host is gfwlist
				[ -f /var/etc/dnsmasq-go.d/02-ipset.conf ] || {
				awk '!/^$/&&!/^#/{printf("ipset=/%s/'"china-banned"'\n",$0)}' \
					/etc/gfwlist/china-banned > /var/etc/dnsmasq-go.d/02-ipset.conf

				awk '!/^$/&&!/^#/{printf("ipset=/%s/'"china-banned"'\n",$0)}' \
					/etc/gfwlist/userlist >> /var/etc/dnsmasq-go.d/02-ipset.conf
				}
				;;
			youku)
				mkdir -p /var/etc/dnsmasq-go.d
				vt_np_ipset=""
				ipset create unblock-youku hash:ip maxelem 65536 2>/dev/null
				iptables -t nat -A shadowsocksr_pre -m set ! --match-set unblock-youku dst -j RETURN
				awk '!/^$/&&!/^#/{printf("ipset=/%s/'"unblock-youku"'\n",$0)}' \
					/etc/gfwlist/unblock-youku > /var/etc/dnsmasq-go.d/02-ipset.conf
				;;

			nochina)
				iptables -t nat -A shadowsocksr_pre -s $host -m set --match-set $vt_np_ipset dst -j RETURN
				;;
			game)
				iptables -t nat -A shadowsocksr_pre -s $host  -m set --match-set $vt_np_ipset dst -j RETURN
				iptables -t mangle -A SSRUDP -s $host  -m set --match-set $vt_np_ipset dst -j RETURN
				ip rule add fwmark 1 lookup 100
				ip route add local default dev lo table 100
				iptables -t mangle -A SSRUDP -s $host  -p udp -j TPROXY --on-port $SS_REDIR_PORT --tproxy-mark 0x01/0x01
				;;
			game2)
				mkdir -p /var/etc/dnsmasq-go.d
				ipset create china-banned hash:ip maxelem 65536 2>/dev/null
				iptables -t nat -A shadowsocksr_pre -s $host -m set ! --match-set china-banned dst -j RETURN
				iptables -t nat -A shadowsocksr_pre -s $host -m set --match-set $vt_np_ipset dst -j RETURN
				echo this $host is gfwlist

				iptables -t mangle -A SSRUDP -s $host  -m set --match-set $vt_np_ipset dst -j RETURN
				ip rule add fwmark 1 lookup 100
				ip route add local default dev lo table 100
				iptables -t mangle -A SSRUDP -s $host  -p udp -j TPROXY --on-port $SS_REDIR_PORT --tproxy-mark 0x01/0x01

				[ -f /var/etc/dnsmasq-go.d/02-ipset.conf ] || {
				awk '!/^$/&&!/^#/{printf("ipset=/%s/'"china-banned"'\n",$0)}' \
					/etc/gfwlist/china-banned > /var/etc/dnsmasq-go.d/02-ipset.conf

				awk '!/^$/&&!/^#/{printf("ipset=/%s/'"china-banned"'\n",$0)}' \
					/etc/gfwlist/userlist >> /var/etc/dnsmasq-go.d/02-ipset.conf
				}
				;;
			all)
				;;

			normal)
				;;
		esac
		iptables -t nat -A shadowsocksr_pre -s $host -p tcp -j REDIRECT --to $SS_REDIR_PORT #内网访问控制
	done

	case "$vt_proxy_mode" in
		G) 
			;;
		S)#alex:所有境外IP
			iptables -t nat -A shadowsocksr_pre -m set --match-set $vt_np_ipset dst -j RETURN
			;;
		M)#alex:gfwlist
			ipset create $vt_gfwlist hash:ip maxelem 65536 2>/dev/null
			iptables -t nat -A shadowsocksr_pre -m set ! --match-set $vt_gfwlist dst -j RETURN
			iptables -t nat -A shadowsocksr_pre -m set --match-set $vt_np_ipset dst -j RETURN
			;;
		V)
			vt_np_ipset=""
			ipset create $vt_gfwlist hash:ip maxelem 65536 2>/dev/null
			iptables -t nat -A shadowsocksr_pre -m set ! --match-set $vt_gfwlist dst -j RETURN
			;;
		GAME)#alex:游戏模式
			iptables -t nat -A shadowsocksr_pre -m set --match-set $vt_np_ipset dst -j RETURN
			iptables -t mangle -A SSRUDP -m set --match-set $vt_np_ipset dst -j RETURN
			ip rule add fwmark 1 lookup 100
			ip route add local default dev lo table 100
			iptables -t mangle -A SSRUDP -p udp -j TPROXY --on-port $SS_REDIR_PORT --tproxy-mark 0x01/0x01

			;;
		GAME2)
			ipset create china-banned hash:ip maxelem 65536 2>/dev/null
			iptables -t nat -A shadowsocksr_pre -m set ! --match-set china-banned dst -j RETURN
			iptables -t nat -A shadowsocksr_pre -m set --match-set $vt_np_ipset dst -j RETURN

			iptables -t mangle -A SSRUDP -m set --match-set $vt_np_ipset dst -j RETURN
			ip rule add fwmark 1 lookup 100
			ip route add local default dev lo table 100
			iptables -t mangle -A SSRUDP -p udp -j TPROXY --on-port $SS_REDIR_PORT --tproxy-mark 0x01/0x01

			;;
		DIRECT)#alex添加访问控制
			iptables -t nat -A shadowsocksr_pre -p tcp -j RETURN
			;;
	esac
	local subnet
	#for subnet in $covered_subnets; do #alex:添加局域网软路由支持
	#	iptables -t nat -A shadowsocksr_pre -s $subnet -p tcp -j REDIRECT --to $SS_REDIR_PORT
	#done
	iptables -t nat -A shadowsocksr_pre -p tcp -j REDIRECT --to $SS_REDIR_PORT #alex:添加局域网软路由支持
	iptables -t nat -I prerouting_rule -p tcp -j shadowsocksr_pre
	iptables -t mangle -A PREROUTING -j SSRUDP
	if [ "$adbyby" = '1' ];then
		iptables -t nat -A OUTPUT -p tcp -m multiport --dports 80,443 -j shadowsocksr_pre
	fi

	# -----------------------------------------------------------------
	mkdir -p /var/etc/dnsmasq-go.d
	###### Anti-pollution configuration ######
	case "$vt_dns_mode" in
		local) : ;;
		tcp_gfwlist)
			start_pdnsd "$vt_safe_dns" "$vt_dns_mode"
			awk -vs="127.0.0.1#$PDNSD_LOCAL_PORT" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
				/etc/gfwlist/$vt_gfwlist > /var/etc/dnsmasq-go.d/01-pollution.conf
			
			awk -vs="127.0.0.1#$PDNSD_LOCAL_PORT" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
				/etc/gfwlist/userlist >> /var/etc/dnsmasq-go.d/01-pollution.conf

			uci set dhcp.@dnsmasq[0].resolvfile=/tmp/resolv.conf.auto
			uci delete dhcp.@dnsmasq[0].noresolv
			uci commit dhcp
			;;
		tcp_114)
			start_pdnsd "$vt_safe_dns" "$vt_dns_mode"
			echo server=127.0.0.1#$PDNSD_LOCAL_PORT > /var/etc/dnsmasq-go.d/01-pollution.conf
			uci set dhcp.@dnsmasq[0].resolvfile=/tmp/resolv.conf.auto
			uci delete dhcp.@dnsmasq[0].noresolv
			uci commit dhcp
			;;
		tcp_proxy)
			start_pdnsd "$vt_safe_dns" "$vt_dns_mode"
			echo server=127.0.0.1#$PDNSD_LOCAL_PORT > /var/etc/dnsmasq-go.d/01-pollution.conf
			uci delete dhcp.@dnsmasq[0].resolvfile
			uci set dhcp.@dnsmasq[0].noresolv=1
			uci commit dhcp
			;;
		tunnel_gfwlist)
			/usr/bin/ssr-tunnel -c $SSR_CONF -u -b0.0.0.0 -l$SS_TUNNEL_PORT -s$vt_server_addr -p$vt_server_port -k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_TUNNEL_PIDFILE -L $vt_safe_dns:$vt_safe_dns_port			
			awk -vs="127.0.0.1#$SS_TUNNEL_PORT" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
				/etc/gfwlist/$vt_gfwlist > /var/etc/dnsmasq-go.d/01-pollution.conf
			
			awk -vs="127.0.0.1#$PDNSD_LOCAL_PORT" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
				/etc/gfwlist/userlist >> /var/etc/dnsmasq-go.d/01-pollution.conf

			uci set dhcp.@dnsmasq[0].resolvfile=/tmp/resolv.conf.auto
			uci delete dhcp.@dnsmasq[0].noresolv
			uci commit dhcp
			;;

		safe_only)
			echo server=$vt_safe_dns#$vt_safe_dns_port > /var/etc/dnsmasq-go.d/01-pollution.conf
			uci delete dhcp.@dnsmasq[0].resolvfile
			uci set dhcp.@dnsmasq[0].noresolv=1
			uci commit dhcp
			;;
		tunnel_all)
			/usr/bin/ssr-tunnel -c $SSR_CONF -u -b0.0.0.0 -l$SS_TUNNEL_PORT -s$vt_server_addr -p$vt_server_port -k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_TUNNEL_PIDFILE -L $vt_safe_dns:$vt_safe_dns_port
			echo server=127.0.0.1#$SS_TUNNEL_PORT > /var/etc/dnsmasq-go.d/01-pollution.conf
			uci delete dhcp.@dnsmasq[0].resolvfile
			uci set dhcp.@dnsmasq[0].noresolv=1
			uci commit dhcp
			;;
	esac
	

	###### dnsmasq-to-ipset configuration ######
	case "$vt_proxy_mode" in
		M | GAME2)
			[ -f /var/etc/dnsmasq-go.d/02-ipset.conf ] || {
			awk '!/^$/&&!/^#/{printf("ipset=/%s/'"$vt_gfwlist"'\n",$0)}' \
				/etc/gfwlist/$vt_gfwlist > /var/etc/dnsmasq-go.d/02-ipset.conf

			awk '!/^$/&&!/^#/{printf("ipset=/%s/'"$vt_gfwlist"'\n",$0)}' \
				/etc/gfwlist/userlist >> /var/etc/dnsmasq-go.d/02-ipset.conf
			}
			;;
			
		V)
			awk '!/^$/&&!/^#/{printf("ipset=/%s/'"$vt_gfwlist"'\n",$0)}' \
				/etc/gfwlist/$vt_gfwlist > /var/etc/dnsmasq-go.d/02-ipset.conf
			;;
	esac

	# -----------------------------------------------------------------
	###### Restart main 'dnsmasq' service if needed ######
	if ls /var/etc/dnsmasq-go.d/* >/dev/null 2>&1; then
		mkdir -p /tmp/dnsmasq.d
		echo 准备生成/tmp/dnsmasq.d/dnsmasq-go.conf！！！！！！！！！！！！！！！！！！
		cat > /tmp/dnsmasq.d/dnsmasq-go.conf <<EOF
conf-dir=/var/etc/dnsmasq-go.d
EOF
		/etc/init.d/dnsmasq restart

		# Check if DNS service was really started
		local dnsmasq_ok=N
		local i
		for i in 0 1 2 3 4 5 6 7; do
			sleep 1
			local dnsmasq_pid=`cat /var/run/dnsmasq.pid 2>/dev/null`
			if [ -n "$dnsmasq_pid" ]; then
				if kill -0 "$dnsmasq_pid" 2>/dev/null; then
					dnsmasq_ok=Y
					break
				fi
			fi
			[ ! -d /var/run/dnsmasq ] && continue
			for files in /var/run/dnsmasq/*; do
				local dnsmasq_pid2=`cat $files`
				if [ -n "$dnsmasq_pid2" ]; then
					if kill -0 "$dnsmasq_pid2" 2>/dev/null; then
						dnsmasq_ok=Y
						break
					fi
				fi
			done
			[ "$dnsmasq_ok" == Y ] && break
		done
		echo dnsmasq_pid是-----$dnsmasq_pid ------------ok是$dnsmasq_ok
		if [ "$dnsmasq_ok" != Y ]; then
			echo "WARNING: Attached dnsmasq rules will cause the service startup failure. Removed those configurations."
			rm -f /tmp/dnsmasq.d/dnsmasq-go.conf
			/etc/init.d/dnsmasq restart
		fi
	fi
}

stop()
{
	local vt_proxy_mode=`uci get shadowsocksr.@shadowsocksr[0].proxy_mode`
	local vt_gfwlist=`__gfwlist_by_mode $vt_proxy_mode`

	# -----------------------------------------------------------------
	rm -rf /var/etc/dnsmasq-go.d
	uci set dhcp.@dnsmasq[0].resolvfile=/tmp/resolv.conf.auto
	uci delete dhcp.@dnsmasq[0].noresolv
	uci commit dhcp
	if [ -f /tmp/dnsmasq.d/dnsmasq-go.conf ]; then
		rm -f /tmp/dnsmasq.d/dnsmasq-go.conf
		/etc/init.d/dnsmasq restart
	fi

	stop_pdnsd

	# -----------------------------------------------------------------
	if iptables -t nat -F shadowsocksr_pre 2>/dev/null; then
		while iptables -t nat -D prerouting_rule -p tcp -j shadowsocksr_pre 2>/dev/null; do :; done
		iptables -t nat -D OUTPUT -p tcp -m multiport --dports 80,443 -j shadowsocksr_pre 2>/dev/null
		iptables -t nat -X shadowsocksr_pre 2>/dev/null
	fi
	#alex:添加游戏模式
	if iptables -t mangle -F SSRUDP 2>/dev/null; then 
		while iptables -t mangle -D PREROUTING -j SSRUDP 2>/dev/null; do :; done
		iptables -t mangle -X SSRUDP 2>/dev/null
	fi

	# -----------------------------------------------------------------
	[ "$KEEP_GFWLIST" = Y ] || ipset destroy "$vt_gfwlist" 2>/dev/null

	# -----------------------------------------------------------------
	if [ -f $SS_REDIR_PIDFILE ]; then
		kill -9 `cat $SS_REDIR_PIDFILE`
		rm -f $SS_REDIR_PIDFILE
	fi
	if [ -f $SS_TUNNEL_PIDFILE ]; then
		kill -9 `cat $SS_TUNNEL_PIDFILE`
		rm -f $SS_TUNNEL_PIDFILE
	fi
}


restart()
{
	KEEP_GFWLIST=Y
	stop
	start
}

# $1: upstream DNS server
start_pdnsd()
{
	local safe_dns="$1"
	local dns_mode="$2"
	

	local tcp_dns_list="208.67.222.222, 208.67.220.220" #alex:给pdnsd使用的可靠的国外dns服务器
	
	case "$dns_mode" in
		local) : ;;
		tcp_gfwlist)
			[ -n "$safe_dns" ] && tcp_dns_list="$safe_dns,$tcp_dns_list"
			safe_dns="114.114.114.114"
			;;
		tcp_114)
			safe_dns="114.114.114.114"
			;;
		tcp_proxy)
			[ -n "$safe_dns" ] && tcp_dns_list="$safe_dns,$tcp_dns_list"
			;;
	esac
	killall -9 pdnsd 2>/dev/null && sleep 1
	mkdir -p /var/etc /var/pdnsd
	cat > /var/etc/pdnsd.conf <<EOF #alex:pdnsd配置文件在此
global {
	perm_cache=512;        # dns缓存大小，单位KB，建议不要写的太大
	cache_dir="/var/pdnsd";     # 缓存文件的位置
	server_ip = 0.0.0.0;        # pdnsd监听的网卡，0.0.0.0是全部网卡
	server_port=$PDNSD_LOCAL_PORT;           # pdnsd监听的端口，不要和别的服务冲突即可
	status_ctl = on;
        paranoid=on;                  # 二次请求模式，如果请求主DNS服务器返回的是垃圾地址，就向备用服务器请求
   	query_method=tcp_only;      # 请求模式，推荐使用仅TCP模式，UDP模式一般需要二次请求
    	neg_domain_pol = off;  
    	par_queries = 400;          # 最多同时请求数
    	min_ttl = 1d;               # DNS结果最短缓存时间
    	max_ttl = 1w;               # DNS结果最长缓存时间
    	timeout = 10;               # DNS请求超时时间，单位秒
}
server {  
   label = "routine";         # 这个随便写  
    ip = $safe_dns;     # 这里为主要上级 dns 的 ip 地址，建议填写一个当地最快的DNS地址  
    timeout = 5;              # DNS请求超时时间
    reject = 74.125.127.102,  # 以下是脏IP，也就是DNS污染一般会返回的结果，如果收到如下DNS结果会触发二次请求（TCP协议一般不会碰到脏IP）
        74.125.155.102,  
        74.125.39.102,  
        74.125.39.113,  
        209.85.229.138,  
        128.121.126.139,  
        159.106.121.75,  
        169.132.13.103,  
        192.67.198.6,  
        202.106.1.2,  
        202.181.7.85,  
        203.161.230.171,  
        203.98.7.65,  
        207.12.88.98,  
        208.56.31.43,  
        209.145.54.50,  
        209.220.30.174,  
        209.36.73.33,  
        211.94.66.147,  
        213.169.251.35,  
        216.221.188.182,  
        216.234.179.13,  
        243.185.187.39,  
        37.61.54.158,  
        4.36.66.178,  
        46.82.174.68,  
        59.24.3.173,  
        64.33.88.161,  
        64.33.99.47,  
        64.66.163.251,  
        65.104.202.252,  
        65.160.219.113,  
        66.45.252.237,  
        69.55.52.253,  
        72.14.205.104,  
        72.14.205.99,  
        78.16.49.15,  
        8.7.198.45,  
        93.46.8.89,  
        37.61.54.158,  
        243.185.187.39,  
        190.93.247.4,  
        190.93.246.4,  
        190.93.245.4,  
        190.93.244.4,  
        65.49.2.178,  
        189.163.17.5,  
        23.89.5.60,  
        49.2.123.56,  
        54.76.135.1,  
        77.4.7.92,  
        118.5.49.6,  
        159.24.3.173,  
        188.5.4.96,  
        197.4.4.12,  
        220.250.64.24,  
        243.185.187.30,  
        249.129.46.48,  
        253.157.14.165;  
    reject_policy = fail;  
    exclude = ".google.com",  
        ".cn",              #排除国内DNS解析，如果正常翻，则可以在前面加#注释  
        ".baidu.com",       #排除国内DNS解析，如果正常翻，则可以在前面加#注释  
        ".qq.com",          #排除国内DNS解析，如果正常翻，则可以在前面加#注释  
        ".gstatic.com",  
        ".googleusercontent.com",  
        ".googlepages.com",  
        ".googlevideo.com",  
        ".googlecode.com",  
        ".googleapis.com",  
        ".googlesource.com",  
        ".googledrive.com",  
        ".ggpht.com",  
        ".youtube.com",  
        ".youtu.be",  
        ".ytimg.com",  
        ".twitter.com",  
        ".facebook.com",  
        ".fastly.net",  
        ".akamai.net",  
        ".akamaiedge.net",  
        ".akamaihd.net",  
        ".edgesuite.net",  
        ".edgekey.net";  
}
server {  
    # 以下为备用DNS服务器的配置，也是二次请求服务器的配置
    label = "special";                  # 这个随便写  
    ip = $tcp_dns_list; # 这里为备用DNS服务器的 ip 地址  
    port = 5353;                        # 推荐使用53以外的端口（DNS服务器必须支持） 
    proxy_only = on;
    timeout = 5;  
}  
EOF
#alex:写入配置文件结束符
	/usr/sbin/pdnsd -c /var/etc/pdnsd.conf -d
	case "$vt_dns_mode" in
		local) : ;;
		tcp_gfwlist)
			if iptables -t nat -N pdnsd_output; then
				iptables -t nat -A pdnsd_output -p tcp -j REDIRECT --to $SS_REDIR_PORT
			fi
			iptables -t nat -I OUTPUT -p tcp --dport 53 -j pdnsd_output
			;;
		tcp_114)
			if iptables -t nat -F pdnsd_output 2>/dev/null; then
				while iptables -t nat -D OUTPUT -p tcp --dport 53 -j pdnsd_output 2>/dev/null; do :; done
				iptables -t nat -X pdnsd_output
			fi
			;;
		tcp_proxy)
			if iptables -t nat -N pdnsd_output; then
				iptables -t nat -A pdnsd_output -m set --match-set $vt_np_ipset dst -j RETURN
				iptables -t nat -A pdnsd_output -p tcp -j REDIRECT --to $SS_REDIR_PORT
			fi
			iptables -t nat -I OUTPUT -p tcp --dport 53 -j pdnsd_output
			;;
	esac
}

stop_pdnsd()
{
	if iptables -t nat -F pdnsd_output 2>/dev/null; then
		while iptables -t nat -D OUTPUT -p tcp --dport 53 -j pdnsd_output 2>/dev/null; do :; done
		iptables -t nat -X pdnsd_output
	fi
	
	[ -f /var/run/pdnsd.pid ] || {
		killall -9 pdnsd 2>/dev/null #alex:防止意外终止独立pdnsd
		rm -rf /var/pdnsd
		rm -f /var/etc/pdnsd.conf
	}
}
