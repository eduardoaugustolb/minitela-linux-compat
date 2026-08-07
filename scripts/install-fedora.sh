#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/minitela_VERSION_amd64.deb" >&2
  exit 64
fi

deb_file=$1
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if [[ $EUID -eq 0 ]]; then
  run_root() { "$@"; }
else
  run_root() { sudo "$@"; }
fi

if [[ ! -f $deb_file ]]; then
  echo "Package not found: $deb_file" >&2
  exit 66
fi
if ! ar t "$deb_file" | grep -qx 'debian-binary'; then
  echo 'The supplied file is not a Debian package.' >&2
  exit 65
fi

run_root dnf install -y binutils libayatana-appindicator-gtk3 socat

stage_dir=$(mktemp -d)
trap 'rm -rf -- "$stage_dir"' EXIT
data_member=$(ar t "$deb_file" | awk '/^data\.tar\./ { print; exit }')
if [[ -z $data_member ]]; then
  echo 'The Debian package has no data archive.' >&2
  exit 65
fi

case "$data_member" in
  *.tar.xz) tar_extract=(tar -xJf -) ;;
  *.tar.gz) tar_extract=(tar -xzf -) ;;
  *.tar.zst) tar_extract=(tar --zstd -xf -) ;;
  *.tar.bz2) tar_extract=(tar -xjf -) ;;
  *.tar) tar_extract=(tar -xf -) ;;
  *)
    echo "Unsupported data archive: $data_member" >&2
    exit 65
    ;;
esac

ar p "$deb_file" "$data_member" | "${tar_extract[@]}" -C "$stage_dir"

if [[ ! -x $stage_dir/usr/share/minitela/minitela ]]; then
  echo 'The package does not contain the expected Minitela executable.' >&2
  exit 65
fi

run_root install -d /usr/share /etc /usr/lib/systemd/system-sleep /usr/local/bin
if [[ -d $stage_dir/etc ]]; then
  run_root cp -a "$stage_dir/etc/." /etc/
fi
run_root cp -a "$stage_dir/usr/." /usr/
if [[ -d $stage_dir/lib/systemd/system-sleep ]]; then
  run_root cp -a "$stage_dir/lib/systemd/system-sleep/." /usr/lib/systemd/system-sleep/
fi

run_root install -m 0755 "$repo_dir/scripts/minitela-show" /usr/local/bin/minitela-show
run_root install -m 0755 "$repo_dir/scripts/dpkg-query" /usr/local/bin/dpkg-query

# Do not replace a real iwgetid installed by another package.
if [[ ! -e /usr/sbin/iwgetid ]] || cmp -s "$repo_dir/scripts/iwgetid" /usr/sbin/iwgetid; then
  run_root install -m 0755 "$repo_dir/scripts/iwgetid" /usr/sbin/iwgetid
else
  echo 'Keeping existing /usr/sbin/iwgetid.'
fi

run_root install -Dm 0644 /dev/stdin /usr/share/applications/minitela.desktop <<'DESKTOP'
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

run_root chmod +x /usr/share/minitela/minitela \
  /usr/share/minitela/reset_infos/reset_infos.sh \
  /usr/lib/systemd/system-sleep/minitela-controller
run_root glib-compile-schemas /usr/share/glib-2.0/schemas
run_root systemd-hwdb update
run_root udevadm control --reload
run_root udevadm trigger

echo 'Minitela installed. Open it from the application menu or run /usr/local/bin/minitela-show.'
