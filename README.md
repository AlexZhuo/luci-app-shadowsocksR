OpenWrt LuCI for ShadowsocksR-libev
===
恩山乌卡卡版本的升级版,已在[该固件][O]中应用
简介
---

本软件包是 [shadowsocksR-libev][openwrt-shadowsocksR] 的 LuCI 控制界面,自带GFWList，国内路由表等分流功能。支持一键智能配置

特性

1、支持基于GFWList的智能分流

2、支持基于国内路由表的智能分流

3、支持国外翻回国内看优酷等视频网站

4、支持基于GFWList的智能DNS解析

5、支持`auth_sha1_v4`,`auth_aes128_md5`,`auth_aes128_sha1`等新型混淆协议

6、支持混淆参数和协议参数

7、支持游戏模式（全局+国内分流UDP转发）

8、支持Adbyby和KoolProxy兼容模式

9、支持GFWlist黑名单和国内路由表手动更新

10、支持ssr-tunnel和pdnsd的DNS解析

11、支持填写服务器域名或者服务器IP

12、可配合HAProxy实现多服务器负载均衡，也可以设置多个备用服务器实现高可用，[详情][haproxy]

13、可配合KCPTUN提高网络质量，[详情][kcptun]

14、支持LAN访问控制（Adbyby/KoolProxy模式需要配合以上二者自己的访问控制功能使用，否则会冲突）

依赖
---

软件包的正常使用需要依赖 `iptables` 和 `ipset`用于流量重定向

`pdnsd`用于TCP协议请求DNS便于转发至SSR服务器

`ip-full` `iptables-mod-tproxy` `kmod-ipt-tproxy` `iptables-mod-nat-extra` 用于实现UDP转发

配置
---

软件包的配置文件路径: `/etc/config/shadowsocksr`   

一般情况下，只需填写服务器IP或者域名，端口，密码，加密方式，混淆，协议即可使用默认的只能模式科学上网，兼顾国内外分流。无需其他复杂操作

编译
---

从 OpenWrt 的 [SDK][openwrt-sdk] 编译  
```bash
# 解压下载好的 SDK
tar xjf OpenWrt-SDK-ar71xx-for-linux-x86_64-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2
cd OpenWrt-SDK-ar71xx-*
# Clone 项目
git clone https://github.com/AlexZhuo/luci-app-shadowsocksR.git package/luci-app-shadowsocksR
# 编译 po2lmo (如果有po2lmo可跳过)
pushd package/luci-app-shadowsocksR/tools/po2lmo
make && sudo make install
popd
# 选择要编译的包 NetWork -> LuCI -> luci-app-shadowsocksR
make menuconfig
# 开始编译
make package/luci-app-shadowsocksR/compile V=99
```

软件截图
---

![demo](https://github.com/AlexZhuo/BreakwallOpenWrt/raw/master/screenshots/ssr1.png)
![demo](https://github.com/AlexZhuo/BreakwallOpenWrt/raw/master/screenshots/ssr2.png)

[O]: http://www.right.com.cn/forum/thread-198649-1-1.html
[openwrt-shadowsocksR]: https://github.com/AlexZhuo/openwrt-shadowsocksr
[openwrt-sdk]: https://wiki.openwrt.org/doc/howto/obtain.firmware.sdk
[haproxy]: https://github.com/AlexZhuo/luci-app-haproxy-tcp
[kcptun]: https://github.com/AlexZhuo/luci-app-kcptun
