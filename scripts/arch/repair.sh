#!/usr/bin/env bash
set -euo pipefail

readonly manifest_path=/var/lib/minitela-linux-compat/manifest
readonly platform_path=/var/lib/minitela-linux-compat/platform
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

if [[ $EUID -eq 0 ]]; then run_root() { "$@"; }; else run_root() { sudo "$@"; }; fi
fail() { echo "Error: $*" >&2; exit 1; }

[[ -r /etc/os-release ]] && . /etc/os-release || true

install_omarchy_tray_bridge() {
  # Omarchy themes can select Yaru-gray, which the packaged yaru-icon-theme
  # does not ship. Qt gives up on a missing named theme before ever reaching
  # hicolor, so the tray renders a placeholder. Bridge the missing theme in
  # the desktop user's local icon directory.
  [[ ${ID:-} == omarchy ]] || return 0
  [[ -d /usr/share/icons/Yaru-gray ]] && return 0
  local shim_user=${SUDO_USER:-$(id -un)}
  if [[ $shim_user == root ]]; then
    echo 'note: skipping Yaru-gray tray bridge (re-run repair as the desktop user via sudo to apply it)' >&2
    return 0
  fi
  local shim_home shim_dir shim_parent shim_group shim_tmp
  shim_home=$(getent passwd "$shim_user" | cut -d: -f6 || true)
  [[ -n $shim_home && -d $shim_home ]] || fail "cannot locate home directory for user: $shim_user"
  shim_dir=$shim_home/.local/share/icons/Yaru-gray
  [[ -d $shim_dir ]] && return 0
  shim_parent=hicolor
  [[ -d /usr/share/icons/Yaru ]] && shim_parent='Yaru,hicolor'
  shim_group=$(id -gn "$shim_user")
  shim_tmp=$(mktemp)
  trap 'unlink "$shim_tmp" 2>/dev/null || true' RETURN
  printf '%s\n' \
    '# managed by minitela-linux-compat: Yaru-gray compatibility bridge' \
    '[Icon Theme]' \
    'Name=Yaru-gray' \
    'Comment=Local bridge for the missing Yaru-gray icon theme' \
    "Inherits=$shim_parent" \
    'Directories=' >"$shim_tmp"
  run_root install -o "$shim_user" -g "$shim_group" -d -m 0755 "$shim_dir"
  run_root install -o "$shim_user" -g "$shim_group" -m 0644 "$shim_tmp" "$shim_dir/index.theme"
  echo "installed Yaru-gray icon-theme bridge for user $shim_user"
}

[[ -f $manifest_path ]] || fail "no managed Minitela installation manifest exists at $manifest_path"
[[ $(run_root cat "$platform_path") == arch ]] || fail 'this installation was not created by the Arch installer; use its matching repair script'
run_root grep -qx '/usr/local/bin/dpkg-query' "$manifest_path" || fail 'installed manifest does not own the dpkg-query compatibility shim'
[[ -x /usr/share/minitela/minitela ]] || fail 'Minitela executable is not installed'

# The vendor executable links directly to gtkmm3, which is not pulled in by
# libappindicator on a minimal Arch/Omarchy installation.
run_root pacman -S --needed --noconfirm gtkmm3 imagemagick

appimage=/usr/share/minitela/resources/MiniPanel-0.1.6.AppImage
vendor_appimage=/usr/share/minitela/resources/MiniPanel-0.1.6.AppImage.vendor
if [[ -e $vendor_appimage ]]; then
  [[ -x $vendor_appimage ]] || fail "managed vendor AppImage is not executable: $vendor_appimage"
else
  [[ -x $appimage ]] || fail "vendor AppImage is not installed: $appimage"
  grep -aFq 'APPIMAGE_EXTRACT_AND_RUN' "$appimage" || fail 'installed GIF editor does not support AppImage extraction mode'
  run_root mv "$appimage" "$vendor_appimage"
fi

# The vendor registers the tray icon by name and never publishes a pixmap,
# so the icon must resolve through an installed icon theme. The vendor file
# is ICO data with a .png name, which PNG loaders reject, so decode it.
if [[ -f /usr/share/minitela/resources/trayIcon.png ]]; then
  icon_path=/usr/share/icons/hicolor/256x256/apps/trayIcon.png
  run_root install -d -m 0755 "$(dirname "$icon_path")"
  run_root magick "ICO:/usr/share/minitela/resources/trayIcon.png[0]" -background none "PNG32:$icon_path"
  run_root chmod 0644 "$icon_path"
  run_root grep -qx "$icon_path" "$manifest_path" || run_root sh -c "printf '%s\n' \"$icon_path\" >> \"$manifest_path\""
fi
install_omarchy_tray_bridge
run_root gtk-update-icon-cache -f /usr/share/icons/hicolor

run_root install -m 0755 "$repo_dir/scripts/common/dpkg-query" /usr/local/bin/dpkg-query
run_root install -m 0755 "$repo_dir/scripts/common/minipanel-appimage-wrapper" "$appimage"
if /usr/local/bin/dpkg-query --showformat='${Version}' --show minitela | grep -qx '1.0.20'; then
  echo 'Minitela compatibility repair completed (including FUSE-free GIF editor launcher).'
else
  fail 'dpkg-query compatibility validation failed'
fi
