--[[
 Customize firewall-banned domain lists - /etc/gfwlist/
 Copyright (c) 2015 Justin Liu
 Author: Justin Liu <rssnsj@gmail.com>
 https://github.com/rssnsj/network-feeds
]]--

local fs = require "nixio.fs"

function sync_value_to_file(value, file)
	value = value:gsub("\r\n?", "\n")
	local old_value = nixio.fs.readfile(file)
	if value ~= old_value then
		nixio.fs.writefile(file, value)
	end
end

m = Map("gfwlist", translate("Domain Lists Settings"),translate("‘GFWList黑名单’可以观察当前域名黑名单，更新后会发生变化;<br>‘海外看视频网站名单’是你在国外回连到国外指定走代理的名单,也就是优酷这样国内视频网站的域名;<br>‘用户自定义网站黑名单’不会被GFWList更新所覆盖，可以手动添加一些强制走代理的网站。<br>注意：点击更新按钮后需要等浏览器自动刷新后才算完成，请勿重复点击，并且自动刷新一遍后需要手动再刷新一遍才能观察到数字变化<br>使用教程请<a href='http://www.right.com.cn/forum/thread-198649-1-1.html'>点击这里</a>"))
s = m:section(TypedSection, "params", translate("Settings"))
s.anonymous = true

for e in fs.dir("/etc/gfwlist") do
	glist = s:option(TextValue, e, translate(e), nil)
	glist.rmempty = false
	glist.rows = 12

	function glist.cfgvalue()
		return nixio.fs.readfile("/etc/gfwlist/" .. e) or ""
	end
	function glist.write(self, section, value)
		sync_value_to_file(value, "/etc/gfwlist/" .. e)
	end
end

button_update_gfwlist = s:option (Button, "_button_update_gfwlist", translate("更新GFWList"),translate("点击后请静待30秒,等页面刷新后到【服务】-【域名列表】中查看是否成功")) 
local gfw_count = luci.sys.exec("grep -c '' /etc/gfwlist/china-banned")
button_update_gfwlist.inputtitle = translate ( "当前规则数目" .. gfw_count .. ",点击更新")
button_update_gfwlist.inputstyle = "apply" 
function button_update_gfwlist.write (self, section, value)
	luci.sys.call ( "/etc/update_gfwlist.sh > /dev/null")
end 

button_update_route = s:option (Button, "_button_update_chinaroute", translate("更新国内路由表"),translate("点击后请静待30秒,如非特殊需要，不用更新该表")) 
local route_count = luci.sys.exec("grep -c '' /etc/ipset/china")
button_update_route.inputtitle = translate ( "当前规则数目" .. route_count .. ",点击更新")
button_update_route.inputstyle = "apply" 
function button_update_route.write (self, section, value)
	luci.sys.call ( "/etc/update_chinaroute.sh > /dev/null")
end 

-- [[ LAN Hosts ]]--
s = m:section(TypedSection, "lan_hosts", translate("LAN Hosts"))
s.template = "cbi/tblsection"
s.addremove = true
s.anonymous = true

o = s:option(Value, "host", translate("Host"))
luci.ip.neighbors(function(x)
	o:value(x["IP address"], "%s (%s)" %{x["IP address"], x["HW address"]})
end)
o.datatype = "ip4addr"
o.rmempty = false

o = s:option(ListValue, "type", translate("Proxy Type"))
o:value("direct", translate("Direct (No Proxy)"))
o:value("normal", translate("Normal"))
o:value("gfwlist", translate("GFW-List based auto-proxy"))
o:value("nochina", translate("All non-China IPs"))
o:value("game", translate("Game Mode"))
o:value("game2", translate("Game Mode V2"))
o:value("all", translate("All Public IPs"))
o:value("youku", translate("Watching Youku overseas"))
o.rmempty = false

o = s:option(Flag, "enable", translate("Enable"))
o.default = "1"
o.rmempty = false

-- ---------------------------------------------------
local apply = luci.http.formvalue("cbi.apply")
if apply then
	os.execute("/etc/init.d/ssr-redir.sh restart >/dev/null 2>&1 &")
end

return m
