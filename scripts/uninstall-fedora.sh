#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

sudo rm -rf -- /usr/share/minitela
sudo rm -f -- \
  /usr/share/applications/minitela.desktop \
  /etc/xdg/autostart/minitela.desktop \
  /etc/udev/hwdb.d/72-keyboard.hwdb \
  /etc/udev/rules.d/99-custom-input.rules \
  /etc/udev/rules.d/99-ttyacm.rules \
  /usr/lib/systemd/system-sleep/minitela-controller \
  /usr/share/glib-2.0/schemas/org.policorp.minitela.gschema.xml \
  /usr/local/bin/minitela-show

if cmp -s "$repo_dir/scripts/dpkg-query" /usr/local/bin/dpkg-query 2>/dev/null; then
  sudo rm -f -- /usr/local/bin/dpkg-query
fi
if cmp -s "$repo_dir/scripts/iwgetid" /usr/sbin/iwgetid 2>/dev/null; then
  sudo rm -f -- /usr/sbin/iwgetid
fi

sudo glib-compile-schemas /usr/share/glib-2.0/schemas
sudo systemd-hwdb update
sudo udevadm control --reload
sudo udevadm trigger

echo 'Minitela compatibility installation removed.'
