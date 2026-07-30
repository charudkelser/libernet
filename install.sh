#!/bin/sh

echo "=========================================="
echo "   Installing Libernet Modern (PHP 8)     "
echo "=========================================="

# 1. Update repo & install dependensi PHP 8 resmi
opkg update && opkg install php8 php8-cgi php8-mod-session php8-mod-curl php8-mod-mbstring php8-mod-fileinfo php8-mod-zip httping resolveip libxml2

# 2. Download Libernet dari Repo Kamu & Atur Folder
rm -rf /root/libernet /www/libernet /tmp/libernet.zip /tmp/libernet-*
curl -sL https://github.com/charudkelser/libernet/archive/refs/heads/utama.zip -o /tmp/libernet.zip
unzip -q /tmp/libernet.zip -d /tmp/

# Pindahkan dari folder ekstrak (otomatis deteksi utama / main)
mv /tmp/libernet-* /root/libernet 2>/dev/null

cp -rf /root/libernet/system/libernet/* /root/libernet/ 2>/dev/null
[ -d /root/libernet/system/bin ] && cp -rf /root/libernet/system/bin/* /usr/bin/
[ -d /root/libernet/system/init.d ] && cp -rf /root/libernet/system/init.d/* /etc/init.d/

ln -sf /root/libernet /www/libernet
chmod -R 755 /root/libernet
[ -f /usr/bin/libernet ] && chmod +x /usr/bin/libernet
[ -f /etc/init.d/libernet ] && chmod +x /etc/init.d/libernet
rm -rf /tmp/libernet.zip /tmp/libernet-*

# 3. Setup Interface & Firewall Libernet
if ! uci get network.libernet > /dev/null 2>&1; then
  echo "Mengonfigurasi firewall Libernet..."
  uci set network.libernet=interface
  uci set network.libernet.proto='none'
  uci set network.libernet.ifname='tun1'
  uci commit
  uci add firewall zone
  uci set firewall.@zone[-1].network='libernet'
  uci set firewall.@zone[-1].name='libernet'
  uci set firewall.@zone[-1].masq='1'
  uci set firewall.@zone[-1].mtu_fix='1'
  uci set firewall.@zone[-1].input='REJECT'
  uci set firewall.@zone[-1].forward='REJECT'
  uci set firewall.@zone[-1].output='ACCEPT'
  uci commit
  uci add firewall forwarding
  uci set firewall.@forwarding[-1].src='lan'
  uci set firewall.@forwarding[-1].dest='libernet'
  uci commit
  /etc/init.d/network restart
fi

# 4. Setting Web Server uHTTPd & PHP 8
ln -sf /usr/bin/php8-cgi /usr/bin/php-cgi
uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
uci commit uhttpd
sed -i 's/disable_functions =.*/disable_functions =/g' /etc/php.ini

# 5. Pasang Menu LuCI Modern (JS View)
mkdir -p /usr/lib/lua/luci/controller /www/luci-static/resources/view
cat <<'EOF' >/usr/lib/lua/luci/controller/libernet.lua
module("luci.controller.libernet", package.seeall)
function index()
    entry({"admin","services","libernet"}, view("libernet"), _("Libernet"), 55).leaf = true
end
EOF

cat <<'EOF' >/www/luci-static/resources/view/libernet.js
'use strict';
'require view';
return view.extend({
  render: function() {
    return E('div', { 'class': 'cbi-section' }, [
      E('h2', {}, 'Libernet'),
      E('iframe', {
        id: 'libernet',
        src: 'http://' + window.location.hostname + '/libernet',
        style: 'width:100%;min-height:650px;border:none;border-radius:2px;'
      })
    ]);
  }
});
EOF

# 6. Restart Service & Clean Cache
rm -f /tmp/luci-indexcache*; rm -rf /tmp/luci-modulecache
service uhttpd restart
[ -f /etc/init.d/libernet ] && /etc/init.d/libernet restart

echo "=========================================="
echo "   Libernet Success Installed! Enjoy!     "
echo "=========================================="
