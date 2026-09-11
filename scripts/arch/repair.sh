#!/usr/bin/env bash
set -euo pipefail

readonly manifest_path=/var/lib/minitela-linux-compat/manifest
readonly platform_path=/var/lib/minitela-linux-compat/platform
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

if [[ $EUID -eq 0 ]]; then run_root() { "$@"; }; else run_root() { sudo "$@"; }; fi
fail() { echo "Error: $*" >&2; exit 1; }

[[ -f $manifest_path ]] || fail "no managed Minitela installation manifest exists at $manifest_path"
[[ $(<"$platform_path") == arch ]] || fail 'this installation was not created by the Arch installer; use its matching repair script'
grep -qx '/usr/local/bin/dpkg-query' "$manifest_path" || fail 'installed manifest does not own the dpkg-query compatibility shim'
[[ -x /usr/share/minitela/minitela ]] || fail 'Minitela executable is not installed'

# The vendor executable links directly to gtkmm3, which is not pulled in by
# libappindicator on a minimal Arch/Omarchy installation.
run_root pacman -S --needed --noconfirm gtkmm3

appimage=/usr/share/minitela/resources/MiniPanel-0.1.6.AppImage
vendor_appimage=/usr/share/minitela/resources/MiniPanel-0.1.6.AppImage.vendor
if [[ -e $vendor_appimage ]]; then
  [[ -x $vendor_appimage ]] || fail "managed vendor AppImage is not executable: $vendor_appimage"
else
  [[ -x $appimage ]] || fail "vendor AppImage is not installed: $appimage"
  grep -aFq 'APPIMAGE_EXTRACT_AND_RUN' "$appimage" || fail 'installed GIF editor does not support AppImage extraction mode'
  run_root mv "$appimage" "$vendor_appimage"
fi

run_root install -m 0755 "$repo_dir/scripts/common/dpkg-query" /usr/local/bin/dpkg-query
run_root install -m 0755 "$repo_dir/scripts/common/minipanel-appimage-wrapper" "$appimage"
if /usr/local/bin/dpkg-query --showformat='${Version}' --show minitela | grep -qx '1.0.20'; then
  echo 'Minitela compatibility repair completed (including FUSE-free GIF editor launcher).'
else
  fail 'dpkg-query compatibility validation failed'
fi
