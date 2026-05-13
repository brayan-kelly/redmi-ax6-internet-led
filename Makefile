include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-internet-led
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Brayan Kelly

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-internet-led
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Internet LED Indicator
  DEPENDS:=+luci-base +rpcd +ubus +uci +libubox +jsonfilter
endef

define Package/luci-app-internet-led/description
  LuCI app and service for controlling router LEDs based on internet connectivity.
endef

define Build/Compile
endef

define Package/luci-app-internet-led/conffiles
/etc/config/internet-led
endef

define Package/luci-app-internet-led/install
	$(CP) ./files/* $(1)/
endef

define Package/luci-app-internet-led/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0

if [ -x /etc/uci-defaults/99_internet-led ]; then
	/etc/uci-defaults/99_internet-led
fi

/etc/init.d/rpcd restart >/dev/null 2>&1 || true
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true
/etc/init.d/internet-led enable >/dev/null 2>&1 || true
/etc/init.d/internet-led start >/dev/null 2>&1 || true

exit 0
endef

define Package/luci-app-internet-led/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0

/etc/init.d/internet-led stop >/dev/null 2>&1 || true
/etc/init.d/internet-led disable >/dev/null 2>&1 || true

exit 0
endef

define Package/luci-app-internet-led/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0

/etc/init.d/rpcd restart >/dev/null 2>&1 || true
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

exit 0
endef

$(eval $(call BuildPackage,luci-app-internet-led))
