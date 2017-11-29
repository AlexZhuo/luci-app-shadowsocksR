#!/bin/sh /etc/rc.common


START=99



SS_REDIR_PORT=7070
SS_TUNNEL_PORT=7071
SS_LOCAL_PORT=7072
SS_REDIR_PIDFILE=/var/run/ssrr-redir-go.pid 
SS_TUNNEL_PIDFILE=/var/run/ssrr-tunnel-go.pid 
SS_LOCAL_PIDFILE=/var/run/ssrr-local-go.pid
PDNSD_LOCAL_PORT=5053 #alex:防止和单独的pdnsd服务冲突
SSR_CONF=/etc/ssrr/shadowsocksr.json
dnsforwarder_pid=/var/run/dnsforwarder/dns.pid
vt_gfwlist=china-banned
vt_np_ipset="chinaip"  # Must be global variable
vt_local_ipset="localip"
vt_remote_ipset="remoteip"
WHITE_SET=whiteset #强制不走代理的ipset

start()
{
	local vt_enabled=`uci get ssrr.@shadowsocksr[0].enabled 2>/dev/null`
	local vt_server_addr=`uci get ssrr.@shadowsocksr[0].server`
	local vt_server_port=`uci get ssrr.@shadowsocksr[0].server_port`
	local vt_password=`uci get ssrr.@shadowsocksr[0].password 2>/dev/null`
	local vt_method=`uci get ssrr.@shadowsocksr[0].method 2>/dev/null`
	local vt_protocol=`uci get ssrr.@shadowsocksr[0].protocol 2>/dev/null`
	local vt_obfs=`uci get ssrr.@shadowsocksr[0].obfs 2>/dev/null`
	local vt_obfs_param=`uci get ssrr.@shadowsocksr[0].obfs_param 2>/dev/null`
	local vt_protocol_param=`uci get ssrr.@shadowsocksr[0].protocol_param 2>/dev/null`
	local vt_timeout=`uci get ssrr.@shadowsocksr[0].timeout 2>/dev/null`
	local vt_safe_dns=`uci get ssrr.@shadowsocksr[0].safe_dns 2>/dev/null`
	local vt_safe_dns_port=`uci get ssrr.@shadowsocksr[0].safe_dns_port 2>/dev/null`
	local vt_proxy_mode=`uci get ssrr.@shadowsocksr[0].proxy_mode 2>/dev/null`
	local vt_dns_mode=`uci get ssrr.@shadowsocksr[0].dns_mode 2>/dev/null`
	local adbyby=`uci get ssrr.@shadowsocksr[0].adbyby 2>/dev/null`
	local white=`uci get ssrr.@shadowsocksr[0].white 2>/dev/null`
	local tool=`uci get ssrr.@shadowsocksr[0].tool 2>/dev/null`
	local red_type=`uci get ssrr.@shadowsocksr[0].red_type 2>/dev/null`
	local username=`uci get ssrr.@shadowsocksr[0].username 2>/dev/null`
	local enable_local=`uci get ssrr.@shadowsocksr[0].enable_local 2>/dev/null`
	local ssr_local_port=`uci get ssrr.@shadowsocksr[0].ssr_local_port 2>/dev/null`
	# $covered_subnets, $local_addresses are not required
	local covered_subnets=`uci get ssrr.@shadowsocksr[0].covered_subnets 2>/dev/null`
	local local_addresses=`uci get ssrr.@shadowsocksr[0].local_addresses 2>/dev/null`

	

	# -----------------------------------------------------------------
	if [ "$vt_enabled" = 0 ]; then
		echo "WARNING: Shadowsocksr is disabled."
		return 1
	fi

	if [ -z "$vt_server_addr" -o -z "$vt_server_port" ]; then
		echo "WARNING: Shadowsocksr not fully configured, not starting."
		return 1
	fi

	[ -z "$vt_proxy_mode" ] && vt_proxy_mode=S #默认是境外IP模式
	[ -z "$vt_dns_mode" ] && vt_dns_mode=tcp_gfwlist #默认是GFWList的DNS模式
	[ -z "$vt_method" ] && vt_method=table
	[ -z "$vt_timeout" ] && vt_timeout=60
	[ -z "$tool" ] && tool=ShadowsocksR
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

	# -----------------------------------------------------------------
	
	case "$tool" in
		ShadowsocksR)
			###### shadowsocksr ######
			cat > $SSR_CONF <<EOF
{
	"server": "$vt_server_addr",
	"server_port": $vt_server_port,
	"local_address": "0.0.0.0",
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
			/usr/bin/ssrr-redir -c $SSR_CONF -u -b0.0.0.0 -l$SS_REDIR_PORT -s$vt_server_addr -p$vt_server_port \
				-k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_REDIR_PIDFILE || return 1
			
			[ $enable_local = 1 ] && [ "$ssr_local_port" -gt "1" ] && {
				echo ssrr-local enabled!
				/usr/bin/ssrr-local -c $SSR_CONF -u -b0.0.0.0 -l$ssr_local_port -s$vt_server_addr -p$vt_server_port \
					-k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_LOCAL_PIDFILE || return 1
			}
			
			;;
		Shadowsocks)
			cat > $SSR_CONF <<EOF
{
	"server": "$vt_server_addr",
	"server_port": $vt_server_port,
	"local_address": "0.0.0.0",
	"password": "$vt_password",
	"method": "$vt_method",
	"timeout": "$vt_timeout",
	"fast_open": false
}
EOF
			sleep 1
			/usr/bin/ssrr-redir -c $SSR_CONF -u -b0.0.0.0 -l$SS_REDIR_PORT -s$vt_server_addr -p$vt_server_port \
			-k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_REDIR_PIDFILE || return 1
			
			[ $enable_local = 1 ] && [ "$ssr_local_port" -gt "1" ] && {
				echo ssrr-local enabled!
				/usr/bin/ssrr-local -u -b0.0.0.0 -l$ssr_local_port -s$vt_server_addr -p$vt_server_port \
					-k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_LOCAL_PIDFILE || return 1
			}
			;;
		Redsocks2)
			cat > $SSR_CONF <<EOF
base {
  log_debug = off; 
  log_info = on;
  daemon = on;
  redirector= iptables;
}
redsocks {
 local_ip = 0.0.0.0;
 local_port = $SS_REDIR_PORT;
 ip = $vt_server_addr;
 port = $vt_server_port;
 type = $red_type; 
 autoproxy = 0;
 timeout = 13;			
EOF
			[ ! -z $username ] && {
				echo "login = $username;" >> $SSR_CONF
				echo "password = $vt_password;" >> $SSR_CONF
			}
			echo "}" >> $SSR_CONF
			
			if [ "$red_type" = "socks5" ]; then
				echo enable redsocks udp
				cat >> $SSR_CONF <<EOF
redudp {
	local_ip = 0.0.0.0;
	local_port = $SS_REDIR_PORT;
	ip = $vt_server_addr;
	port = $vt_server_port;
	type = $red_type;
	udp_timeout = 20;
EOF
				[ ! -z $username ] && {
					echo "login = $username;" >> $SSR_CONF
					echo "password = $vt_password;" >> $SSR_CONF
				}
				echo "}" >> $SSR_CONF
			fi
			
			redsocks2 -c $SSR_CONF -p $SS_REDIR_PIDFILE || return 1
			;;
	esac
	
	
		
		
	# IPv4 firewall rules
	iptables -t nat -N ssrr_pre
	iptables -t nat -F ssrr_pre
	iptables -t mangle -N SSRUDP
	iptables -t mangle -F SSRUDP

	china_file="/etc/ssrr/china_route"
	user_local_file="/etc/ssrr/user_local_ip"
	user_remote_file="/etc/ssrr/user_remote_ip"
	
	[ -f $user_local_file ] && {
		echo add local ip  $user_local_file $vt_local_ipset
		ipset create $vt_local_ipset hash:net family inet hashsize 1024 maxelem 65536
		awk '{system("ipset add localip "$0)}' $user_local_file
	}

	[ -f $user_remote_file ] && {
		echo add remote ip  $user_remote_file $vt_remote_ipset
		ipset create $vt_remote_ipset hash:net family inet hashsize 1024 maxelem 65536
		awk '{system("ipset add remoteip "$0)}' $user_remote_file
	}

	[ -f $china_file ] && {
		ipset create $vt_np_ipset hash:net family inet hashsize 1024 maxelem 65536
	}

	iptables -t nat -A ssrr_pre -m set --match-set $vt_local_ipset dst -j RETURN || { #应对没有安装ipset的用户
		iptables -t nat -A ssrr_pre -d 10.0.0.0/8 -j RETURN
		iptables -t nat -A ssrr_pre -d 127.0.0.0/8 -j RETURN
		iptables -t nat -A ssrr_pre -d 172.16.0.0/12 -j RETURN
		iptables -t nat -A ssrr_pre -d 192.168.0.0/16 -j RETURN
		iptables -t nat -A ssrr_pre -d 127.0.0.0/8 -j RETURN
		iptables -t nat -A ssrr_pre -d 224.0.0.0/3 -j RETURN
	}
	

	iptables -t mangle -A SSRUDP -m set --match-set $vt_local_ipset dst -j RETURN || { #应对没有安装ipset的用户
		iptables -t mangle -A SSRUDP -d 10.0.0.0/8 -j RETURN
		iptables -t mangle -A SSRUDP  -d 127.0.0.0/8 -j RETURN
		iptables -t mangle -A SSRUDP  -d 172.16.0.0/12 -j RETURN
		iptables -t mangle -A SSRUDP  -d 192.168.0.0/16 -j RETURN
		iptables -t mangle -A SSRUDP  -d 127.0.0.0/8 -j RETURN
		iptables -t mangle -A SSRUDP  -d 224.0.0.0/3 -j RETURN
	}
	
	if [ "$white" = 1 ]; then #强制不代理域名
		ipset create $WHITE_SET hash:net family inet hashsize 1024 maxelem 65536 2>/dev/null
		iptables -t nat -A ssrr_pre -m set --match-set $WHITE_SET dst -j RETURN
		iptables -t mangle -A SSRUDP -m set --match-set $WHITE_SET dst -j RETURN
	fi

	ip rule add fwmark 1 lookup 100
	ip route add local default dev lo table 100

	iptables -t nat -A ssrr_pre -d $vt_server_addr -j RETURN
	iptables -t nat -A ssrr_pre -p tcp  -m set --match-set $vt_remote_ipset dst -j REDIRECT --to $SS_REDIR_PORT #强制走代理的IP
	iptables -t mangle -A SSRUDP -d $vt_server_addr -j RETURN
	iptables -t mangle -A SSRUDP -p udp --dport 53 -j RETURN

	COUNTER=0 #添加内网访问控制
	while true
	do	
		local host=`uci get ssrr.@lan_hosts[$COUNTER].host 2>/dev/null`
		local lan_enable=`uci get ssrr.@lan_hosts[$COUNTER].enable 2>/dev/null`
		local mType=`uci get ssrr.@lan_hosts[$COUNTER].type 2>/dev/null`

		if [ -z "$host" ] || [ -z "$mType" ]; then
			echo $COUNTER lan devices
			break
		fi
		echo now is $host
		COUNTER=$(($COUNTER+1))
		if [ "$lan_enable" = "0" ]; then
			continue
		fi

		case $mType in
			direct)
				iptables -t nat -A ssrr_pre -s $host -j RETURN
				iptables -t mangle -A SSRUDP -s $host -j RETURN
				;;
			gfwlist)
				ipset create $vt_gfwlist hash:net family inet hashsize 1024 maxelem 65536 2>/dev/null
				iptables -t nat -A ssrr_pre -s $host -m set ! --match-set $vt_gfwlist dst -j RETURN
				iptables -t nat -A ssrr_pre -s $host -m set --match-set $vt_np_ipset dst -j RETURN
				iptables -t nat -A ssrr_pre -s $host -p udp --dport 53 -j REDIRECT --to-ports 53
				iptables -t mangle -A SSRUDP -s $host -j RETURN
				echo this $host is gfwlist
				#开启dnsforwarder
				start_dnsforwarder "$vt_safe_dns" "$vt_dns_mode"
				;;

			nochina)#绕过中国大陆IP
				iptables -t nat -A ssrr_pre -s $host -m set --match-set $vt_np_ipset dst -j RETURN
				iptables -t mangle -A SSRUDP -s $host -j RETURN
				#开启dnsforwarder
				start_dnsforwarder "$vt_safe_dns" "$vt_dns_mode"
				;;
			game)
				iptables -t nat -A ssrr_pre -s $host  -m set --match-set $vt_np_ipset dst -j RETURN
				iptables -t mangle -A SSRUDP -s $host  -m set --match-set $vt_np_ipset dst -j RETURN
				iptables -t mangle -A SSRUDP -s $host  -p udp -j TPROXY --on-port $SS_REDIR_PORT --tproxy-mark 0x01/0x01
				;;
			all)
				;;

			normal)
				;;
		esac
		iptables -t nat -A ssrr_pre -s $host -p tcp -j REDIRECT --to $SS_REDIR_PORT #内网访问控制
	done
	
	

	case "$vt_proxy_mode" in
		G) #全局
			;;
		S)#alex:所有境外IP
			iptables -t nat -A ssrr_pre -m set --match-set $vt_np_ipset dst -j RETURN
			;;
		M)#alex:gfwlist
			ipset create $vt_gfwlist hash:net family inet hashsize 1024 maxelem 65536 2>/dev/null
			iptables -t nat -A ssrr_pre -m set ! --match-set $vt_gfwlist dst -j RETURN
			iptables -t nat -A ssrr_pre -m set --match-set $vt_np_ipset dst -j RETURN
			;;
		GAME)#alex:游戏模式
			iptables -t nat -A ssrr_pre -m set --match-set $vt_np_ipset dst -j RETURN
			iptables -t mangle -A SSRUDP -m set --match-set $vt_np_ipset dst -j RETURN
			iptables -t mangle -A SSRUDP -p udp -j TPROXY --on-port $SS_REDIR_PORT --tproxy-mark 0x01/0x01
			;;
		DIRECT)#alex添加访问控制
			iptables -t nat -A ssrr_pre -p tcp -j RETURN
			;;
	esac
	local subnet
	#for subnet in $covered_subnets; do #alex:添加局域网软路由支持
	#	iptables -t nat -A ssrr_pre -s $subnet -p tcp -j REDIRECT --to $SS_REDIR_PORT
	#done
	iptables -t nat -A ssrr_pre -p tcp -j REDIRECT --to $SS_REDIR_PORT #alex:添加局域网软路由支持
	
	if [ "$adbyby" = '1' ];then
		iptables -t nat -A OUTPUT -p tcp -m multiport --dports 80,443 -j ssrr_pre
		PR_NU=`iptables -nvL PREROUTING -t nat |sed 1,2d | sed -n '/KOOLPROXY/='`
		if [ -z "$PR_NU" ]; then
			PR_NU=1
		else
			let PR_NU+=1
		fi
		iptables -t nat -I PREROUTING $PR_NU -j ssrr_pre
	else
		iptables -t nat -I prerouting_rule -j ssrr_pre
	fi
	iptables -t mangle -A PREROUTING -j SSRUDP

	# -----------------------------------------------------------------
	###### Anti-pollution configuration ######
	case "$vt_dns_mode" in
		tcp_gfwlist)
			start_dnsforwarder "$vt_safe_dns" "$vt_dns_mode"
			;;
		tcp_proxy)
			start_dnsforwarder "$vt_safe_dns" "$vt_dns_mode"
			;;
		tunnel_gfwlist) #废弃
			/usr/bin/ssr-tunnel -c $SSR_CONF -u -b0.0.0.0 -l$SS_TUNNEL_PORT -s$vt_server_addr -p$vt_server_port -k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_TUNNEL_PIDFILE -L $vt_safe_dns:$vt_safe_dns_port			
			awk -vs="127.0.0.1#$SS_TUNNEL_PORT" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
				/etc/gfwlist/$vt_gfwlist > /var/etc/dnsmasq-go.d/01-pollution.conf
			
			awk -vs="127.0.0.1#$PDNSD_LOCAL_PORT" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
				/etc/gfwlist/userlist >> /var/etc/dnsmasq-go.d/01-pollution.conf

			uci set dhcp.@dnsmasq[0].resolvfile=/tmp/resolv.conf.auto
			uci delete dhcp.@dnsmasq[0].noresolv
			uci commit dhcp
			;;

		safe_only) #直接全部发到用户指定安全DNS
			iptables -t nat -A ssrr_pre --dport 53 -j DNAT --to-destination $vt_safe_dns:$vt_safe_dns_port
			;;
		tunnel_all) #废弃
			/usr/bin/ssr-tunnel -c $SSR_CONF -u -b0.0.0.0 -l$SS_TUNNEL_PORT -s$vt_server_addr -p$vt_server_port -k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_TUNNEL_PIDFILE -L $vt_safe_dns:$vt_safe_dns_port
			echo server=127.0.0.1#$SS_TUNNEL_PORT > /var/etc/dnsmasq-go.d/01-pollution.conf
			uci delete dhcp.@dnsmasq[0].resolvfile
			uci set dhcp.@dnsmasq[0].noresolv=1
			uci commit dhcp
			;;
	esac

	local ipcount=`ipset list $vt_np_ipset | wc -l`
	echo china ips count is $ipcount
	[ $ipcount -lt "100" ] && {
		echo add china ip  $china_file $vt_np_ipset
		awk '{system("ipset add chinaip "$0)}' $china_file
	}

}

stop()
{
	# -----------------------------------------------------------------
	if iptables -t nat -F ssrr_pre 2>/dev/null; then
		while iptables -t nat -D prerouting_rule -j ssrr_pre 2>/dev/null; do :; done
		while iptables -t nat -D PREROUTING -j ssrr_pre 2>/dev/null; do :; done
		while iptables -t nat -D OUTPUT -p tcp -m multiport --dports 80,443 -j ssrr_pre 2>/dev/null; do :; done
		iptables -t nat -X ssrr_pre 2>/dev/null
	fi
	#alex:添加游戏模式
	if iptables -t mangle -F SSRUDP 2>/dev/null; then 
		while iptables -t mangle -D PREROUTING -j SSRUDP 2>/dev/null; do :; done
		iptables -t mangle -X SSRUDP 2>/dev/null
	fi

	echo clearing ipset
	ipset destroy $vt_local_ipset
	ipset destroy $vt_remote_ipset
	[ $keep_chinaip = 0 ] && ipset destroy $vt_np_ipset

	stop_dnsforwarder

	if [ -f $SS_REDIR_PIDFILE ]; then
		kill -9 `cat $SS_REDIR_PIDFILE`
		rm -f $SS_REDIR_PIDFILE
	fi
	if [ -f $SS_TUNNEL_PIDFILE ]; then
		kill -9 `cat $SS_TUNNEL_PIDFILE`
		rm -f $SS_TUNNEL_PIDFILE
	fi
	if [ -f $SS_LOCAL_PIDFILE ]; then
		kill -9 `cat $SS_LOCAL_PIDFILE`
		rm -f $SS_LOCAL_PIDFILE
	fi
}

keep_chinaip=0

restart()
{
	keep_chinaip=1
	stop
	start
}

# $1: upstream DNS server
start_dnsforwarder()
{
	echo reday to start dnsforwarder by ssr
	
	local safe_dns="$1"
	local dns_mode="$2"

	case "$dns_mode" in
		tcp_gfwlist)
			if iptables -t nat -N pdnsd_output; then
				echo gfwlist dns mode
				iptables -t nat -A pdnsd_output -p tcp -j REDIRECT --to $SS_REDIR_PORT
				iptables -t nat -I OUTPUT -p tcp --dport 53 -j pdnsd_output
				iptables -t nat -A ssrr_pre -p udp --dport 53 -j REDIRECT --to-ports 53
			fi
			;;
		tcp_proxy)
			if iptables -t nat -N pdnsd_output; then
				echo gfwlist dns mode
				iptables -t nat -A pdnsd_output -m set --match-set $vt_np_ipset dst -j RETURN
				iptables -t nat -A pdnsd_output -p tcp -j REDIRECT --to $SS_REDIR_PORT
				iptables -t nat -I OUTPUT -p tcp --dport 53 -j pdnsd_output
				iptables -t nat -A ssrr_pre -p udp --dport 53 -j REDIRECT --to-ports $PDNSD_LOCAL_PORT
			fi
			;;
	esac

	
	
	uci set dnsforwarder.@arguments[0].enabled=1 
	uci set dnsforwarder.@arguments[0].dnsmasq=1
	uci set dnsforwarder.@arguments[0].addr=127.0.0.1:$PDNSD_LOCAL_PORT
	uci set dnsforwarder.@arguments[0].mode=gfw_user
	uci set dnsforwarder.@arguments[0].ipset=1
	uci set dnsforwarder.@arguments[0].ipset_name=china-banned
	[ "$white" = 1 ] && { #启用强制不代理列表
		uci set dnsforwarder.@arguments[0].white=1
		uci set dnsforwarder.@arguments[0].whiteset=$WHITE_SET
		uci set dnsforwarder.@arguments[0].whitedns=114.114.114.114
	}

	uci commit dnsforwarder

	dns_pid1=`ps | awk '$5 ~ /\[dnsforwarder\]/ {print $1}'`
	dns_pid2=`cat $dnsforwarder_pid 2>/dev/null` 

	[ "$dns_pid1" -gt 1 ] && {
		echo dnsforwarder is running,need not start!
		return	
	}
	[ "$dns_pid2" -gt 1 ] && {
		echo dnsforwarder has been started,need not start!
		return	
	}

	echo safe dns = $safe_dns dns mode is $dns_mode
	local white=`uci get ssrr.@shadowsocksr[0].white 2>/dev/null`

	local tcp_dns_list="208.67.222.222,208.67.220.220" #alex:给pdnsd使用的可靠的国外dns服务器
	
	case "$dns_mode" in
		tcp_gfwlist)
			[ -n "$safe_dns" ] && tcp_dns_list="$safe_dns,$tcp_dns_list"
			safe_dns="114.114.114.114"
			;;
		tcp_proxy)
			[ -n "$safe_dns" ] && tcp_dns_list="$safe_dns,$tcp_dns_list"

			;;
	esac


	[ ! -f "/etc/dnsforwarder/dnsforwarder.conf.bak" ] && {
		cp /etc/dnsforwarder/dnsforwarder.conf /etc/dnsforwarder/dnsforwarder.conf.bak
	}
	cat > /etc/dnsforwarder/dnsforwarder.conf <<EOF
LogOn true
LogFileThresholdLength 102400
LogFileFolder /var/log
UDPLocal 0.0.0.0:$PDNSD_LOCAL_PORT
TCPGroup $tcp_dns_list * no
GroupFile
BlockIP 243.185.187.39,46.82.174.68,37.61.54.158,93.46.8.89,59.24.3.173,203.98.7.65,8.7.198.45,78.16.49.15,159.106.121.75,69.63.187.12,31.13.76.8,31.13.64.49
IPSubstituting
BlockNegativeResponse false
Hosts
HostsUpdateInterval 18000
HostsDownloadPath
HostsScript
HostsRetryInterval 30
AppendHosts
BlockIpv6WhenIpv4Exists false
UseCache true
CacheSize 1048576
MemoryCache true
CacheFile
IgnoreTTL false
OverrideTTL -1
MultipleTTL 1
ReloadCache false
OverwriteCache false
DisabledType
DisabledDomain
DisabledList
DomainStatistic false
DomainStatisticTempletFile
StatisticUpdateInterval 29
EOF
/etc/init.d/dnsforwarder restart
}

stop_dnsforwarder()
{
	if iptables -t nat -F pdnsd_output 2>/dev/null; then
		while iptables -t nat -D OUTPUT -p tcp --dport 53 -j pdnsd_output 2>/dev/null; do :; done
		iptables -t nat -X pdnsd_output 2>/dev/null
	fi
	
	uci set dnsforwarder.@arguments[0].enabled=0
	uci commit dnsforwarder
	/etc/init.d/dnsforwarder restart
	[ -f  "/etc/dnsforwarder/dnsforwarder.conf.bak" ] && cp /etc/dnsforwarder/dnsforwarder.conf.bak /etc/dnsforwarder/dnsforwarder.conf
	rm -f /etc/dnsforwarder/dnsforwarder.conf.bak
}
