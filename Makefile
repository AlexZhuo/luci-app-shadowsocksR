include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-shadowsocksR
PKG_VERSION=1.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Alex Zhuo <1886090@gmail.com>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
    SECTION:=utils
    CATEGORY:=Utilities
    TITLE:=luci for shadowsocksR
        DEPENDS:=+shadowsocksr-libev +pdnsd +kmod-ipt-ipopt +iptables-mod-ipopt +ipset +ip-full +iptables-mod-tproxy +kmod-ipt-tproxy +iptables-mod-nat-extra
endef

define Package/$(PKG_NAME)/description
    A luci app for shadowsocksR
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
rm -rf /tmp/luci*
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
    $(CP) ./files/* $(1)/

endef

$(eval $(call BuildPackage,$(PKG_NAME)))
