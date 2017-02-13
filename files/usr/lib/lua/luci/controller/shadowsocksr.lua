module("luci.controller.shadowsocksr", package.seeall)
function index()
		if not nixio.fs.access("/etc/config/shadowsocksr") then
		return
	end
	entry({"admin", "services", "shadowsocksr"},alias("admin", "services", "shadowsocksr","general"),_("ShadowsocksR")).dependent = true
	entry({"admin", "services", "shadowsocksr","general"}, cbi("shadowsocksr/general"),_("General"),10).leaf = true
	entry({"admin", "services", "shadowsocksr","gfwlist"}, cbi("shadowsocksr/gfwlist"),_("GFWlist"),20).leaf = true
end

