--[[
Shadowsocksr LuCI Configuration Page.
References:
 https://github.com/ravageralpha/my_openwrt_mod  - by RA-MOD
 http://www.v2ex.com/t/139438  - by imcczy
 https://github.com/rssnsj/network-feeds  - by Justin Liu
]]--

local fs = require "nixio.fs"

local state_msg = ""
local ssr_redir_on = (luci.sys.call("pidof ssr-redir > /dev/null") == 0)
if ssr_redir_on then	
	state_msg = "<b><font color=\"green\">" .. translate("Running") .. "</font></b>"
else
	state_msg = "<b><font color=\"red\">" .. translate("Not running") .. "</font></b>"
end

m = Map("shadowsocksr", translate("Shadowsocksr Transparent Proxy"),
	translate("A fast secure tunnel proxy that help you get through firewalls on your router").."<br>使用教程请<a href='http://www.right.com.cn/forum/thread-198649-1-1.html'>点击这里</a><br><br>" .. "状态 - " .. state_msg)

s = m:section(TypedSection, "shadowsocksr", translate("Settings"))
s.anonymous = true

-- ---------------------------------------------------
switch = s:option(Flag, "enabled", translate("Enable"))
switch.rmempty = false

server = s:option(Value, "server", translate("Server Address"))
server.optional = false
server.datatype = "host"
server.rmempty = false

server_port = s:option(Value, "server_port", translate("Server Port"))
server_port.datatype = "range(1,65535)"
server_port.optional = false
server_port.rmempty = false

password = s:option(Value, "password", translate("Password"))
password.password = true

method = s:option(ListValue, "method", translate("Encryption Method"))
method:value("table")
method:value("rc4")
method:value("rc4-md5")
method:value("aes-128-cfb")
method:value("aes-192-cfb")
method:value("aes-256-cfb")
method:value("bf-cfb")
method:value("camellia-128-cfb")
method:value("camellia-192-cfb")
method:value("camellia-256-cfb")
method:value("cast5-cfb")
method:value("des-cfb")
method:value("idea-cfb")
method:value("rc2-cfb")
method:value("seed-cfb")
method:value("salsa20")
method:value("chacha20")
method:value("chacha20-ietf")
method:value("aes-128-ctr")

protocol = s:option(ListValue, "protocol", translate("Protocol"))
protocol:value("origin")
protocol:value("verify_simple")
protocol:value("verify_deflate")
protocol:value("verify_sha1")
protocol:value("auth_simple")
protocol:value("auth_sha1")
protocol:value("auth_sha1_v2")
protocol:value("auth_sha1_v4")
protocol:value("auth_aes128_sha1")
protocol:value("auth_aes128_md5")
protocol:value("auth_chain_a")

obfs = s:option(ListValue, "obfs", translate("Obfs"))
obfs:value("plain")
obfs:value("http_simple")
obfs:value("http_post")
obfs:value("tls_simple")
--obfs:value("random_head")
obfs:value("tls1.0_session_auth")
obfs:value("tls1.2_ticket_auth")

s:option(Flag, "more", translate("More Options"),
	translate("Options for advanced users"))

timeout = s:option(Value, "timeout", translate("Timeout"))
timeout.datatype = "range(0,10000)"
timeout.placeholder = "60"
timeout.optional = false
timeout:depends("more", "1")

-- fast_open = s:option(Flag, "fast_open", translate("TCP Fast Open"),
--	translate("Enable TCP fast open, only available on kernel > 3.7.0"))

proxy_mode = s:option(ListValue, "proxy_mode", translate("Proxy Mode"),
	translate("GFW-List mode requires flushing DNS cache") .. "<br /> " ..
	"<a href=\"" .. luci.dispatcher.build_url("admin", "services","shadowsocksr","gfwlist") .. "\">" ..
	translate("Click here to customize your GFW-List") ..
	"</a>")
proxy_mode:value("S", translate("All non-China IPs"))
proxy_mode:value("M", translate("GFW-List based auto-proxy"))
proxy_mode:value("G", translate("All Public IPs"))
proxy_mode:value("V", translate("Watching Youku overseas"))
proxy_mode:value("GAME", translate("Game Mode"))--alex:添加游戏模式
proxy_mode:value("GAME2", translate("Game Mode V2"))--alex:添加游戏模式V2
proxy_mode:value("DIRECT", translate("Direct (No Proxy)"))--alex:添加访问控制
proxy_mode:depends("more", "1")

safe_dns = s:option(Value, "safe_dns", translate("Safe DNS"),
	translate("recommend OpenDNS"))
safe_dns.datatype = "ip4addr"
safe_dns.optional = false
safe_dns.placeholder = "208.67.220.220"
safe_dns:depends("more", "1")

safe_dns_port = s:option(Value, "safe_dns_port", translate("Safe DNS Port"),
	translate("Foreign DNS on UDP port 53 might be polluted"))
safe_dns_port.datatype = "range(1,65535)"
safe_dns_port.placeholder = "443"
safe_dns_port.optional = false
safe_dns_port:depends("more", "1")


dns_mode = s:option(ListValue, "dns_mode", translate("DNS Mode"),
	translate("Suggest using GFW-List based auto-proxy"))
dns_mode:value("tcp_gfwlist", translate("GFW-List based auto-proxy"))
dns_mode:value("tcp_114", translate("Local TCP mode"))
dns_mode:value("tcp_proxy", translate("Remote TCP mode"))
dns_mode:value("tunnel_gfwlist", translate("Tunnel mode based on GFWLIST"))
dns_mode:value("tunnel_all", translate("Tunnel mode for all"))
dns_mode:value("safe_only", translate("Local safe DNS"))
dns_mode:value("local", translate("System default"))
dns_mode:depends("more", "1")

protocol_param = s:option(Value, "protocol_param", translate("Protocol Param"),
	translate("leave it empty is well"))
protocol_param:depends("more", "1")

obfs_param= s:option(Value, "obfs_param", translate("Obfs Param"),
	translate("leave it empty is well"))
obfs_param:depends("more", "1") 
adbyby=s:option(Flag,"adbyby",translate("配合Adbyby或koolproxy使用"),translate("未开启Adbyby或koolproxy时请不要勾选此项"))
adbyby:depends("more", "1") 
adbyby.rmempty=false



-- ---------------------------------------------------
local apply = luci.http.formvalue("cbi.apply")
if apply then
	os.execute("/etc/init.d/ssr-redir.sh restart >/dev/null 2>&1 &")
end

return m
