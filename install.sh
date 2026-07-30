#!/bin/sh

echo "=========================================="
echo "   Installing Libernet (PHP 8 Modern)     "
echo "=========================================="

# 1. Update repo & install paket PHP 8 terbaru + alat pendukung
opkg update && opkg install git git-http php8 php8-cgi php8-mod-session php8-mod-curl php8-mod-mbstring php8-mod-fileinfo php8-mod-zip httping resolveip libxml2

# 2. Persiapan Folder & Download Repo
rm -rf /root/libernet /www/libernet /tmp/libernet-repo
git clone --depth 1 https://github.com/charudkelser/libernet.git /tmp/libernet-repo
mv /tmp/libernet-repo /root/libernet

# Copy sistem bin & init.d jika ada
cp -rf /root/libernet/system/libernet/* /root/libernet/ 2>/dev/null
[ -d /root/libernet/system/bin ] && cp -rf /root/libernet/system/bin/* /usr/bin/
[ -d /root/libernet/system/init.d ] && cp -rf /root/libernet/system/init.d/* /etc/init.d/

# 3. Symlink Folder Web & Izin Akses
ln -sf /root/libernet/web /www/libernet
chmod -R 755 /root/libernet
[ -f /usr/bin/libernet ] && chmod +x /usr/bin/libernet
[ -f /etc/init.d/libernet ] && chmod +x /etc/init.d/libernet

# 4. Patch Path Variable & Config
sed -i "s|LIBERNET_DIR|/root/libernet|g" /root/libernet/web/config.inc.php 2>/dev/null
[ ! -f /root/libernet/system/config.json ] && [ -f /root/libernet/system/config.example.json ] && cp /root/libernet/system/config.example.json /root/libernet/system/config.json

# 5. Ubah Ketergantungan Web Server (uHTTPd) ke PHP 8
ln -sf /usr/bin/php8-cgi /usr/bin/php-cgi
uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
uci commit uhttpd
sed -i 's/disable_functions =.*/disable_functions =/g' /etc/php.ini

# 6. Integrasi Menu LuCI (Modern JS View)
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

# 7. Restart Service
rm -f /tmp/luci-indexcache*; rm -rf /tmp/luci-modulecache
service uhttpd restart
[ -f /etc/init.d/libernet ] && /etc/init.d/libernet restart

echo "=========================================="
echo "   LIBERNET PHP 8 INSTALLED SUCCESSFULLY!  "
echo "=========================================="
