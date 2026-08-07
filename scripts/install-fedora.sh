#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/minitela_VERSION_amd64.deb" >&2
  exit 64
fi

deb_file=$1
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if [[ ! -f $deb_file ]]; then
  echo "Package not found: $deb_file" >&2
  exit 66
fi
if ! ar t "$deb_file" | grep -qx 'debian-binary'; then
  echo 'The supplied file is not a Debian package.' >&2
  exit 65
fi

sudo dnf install -y binutils libayatana-appindicator-gtk3 socat

stage_dir=$(mktemp -d)
trap 'rm -rf -- "$stage_dir"' EXIT
data_member=$(ar t "$deb_file" | awk '/^data\.tar\./ { print; exit }')
if [[ -z $data_member ]]; then
  echo 'The Debian package has no data archive.' >&2
  exit 65
fi

ar p "$deb_file" "$data_member" | tar -x -f - -C "$stage_dir"

if [[ ! -x $stage_dir/usr/share/minitela/minitela ]]; then
  echo 'The package does not contain the expected Minitela executable.' >&2
  exit 65
fi

sudo install -d /usr/share /etc /usr/lib/systemd/system-sleep /usr/local/bin
if [[ -d $stage_dir/etc ]]; then
  sudo cp -a "$stage_dir/etc/." /etc/
fi
sudo cp -a "$stage_dir/usr/." /usr/
if [[ -d $stage_dir/lib/systemd/system-sleep ]]; then
  sudo cp -a "$stage_dir/lib/systemd/system-sleep/." /usr/lib/systemd/system-sleep/
fi

sudo install -m 0755 "$repo_dir/scripts/minitela-show" /usr/local/bin/minitela-show
sudo install -m 0755 "$repo_dir/scripts/dpkg-query" /usr/local/bin/dpkg-query

# Do not replace a real iwgetid installed by another package.
if [[ ! -e /usr/sbin/iwgetid ]] || cmp -s "$repo_dir/scripts/iwgetid" /usr/sbin/iwgetid; then
  sudo install -m 0755 "$repo_dir/scripts/iwgetid" /usr/sbin/iwgetid
else
  echo 'Keeping existing /usr/sbin/iwgetid.'
fi

sudo install -Dm 0644 /dev/stdin /usr/share/applications/minitela.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Name=Minitela
Comment=Aplicação Minitela para controle
Exec=/usr/local/bin/minitela-show
Icon=/usr/share/minitela/resources/minitelaIcon.png
Terminal=false
Type=Application
Categories=Utility;
DESKTOP

sudo chmod +x /usr/share/minitela/minitela \
  /usr/share/minitela/reset_infos/reset_infos.sh \
  /usr/lib/systemd/system-sleep/minitela-controller
sudo glib-compile-schemas /usr/share/glib-2.0/schemas
sudo systemd-hwdb update
sudo udevadm control --reload
sudo udevadm trigger

echo 'Minitela installed. Open it from the application menu or run /usr/local/bin/minitela-show.'
