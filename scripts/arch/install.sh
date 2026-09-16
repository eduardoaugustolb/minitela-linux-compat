#!/usr/bin/env bash
set -euo pipefail

readonly state_dir=/var/lib/minitela-linux-compat
readonly manifest_path="$state_dir/manifest"
readonly platform_path="$state_dir/platform"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/minitela_VERSION_amd64.deb" >&2
  exit 64
fi

deb_file=$1
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

if [[ $EUID -eq 0 ]]; then
  run_root() { "$@"; }
else
  run_root() { sudo "$@"; }
fi

fail() {
  echo "Error: $*" >&2
  exit 1
}

install_omarchy_tray_bridge() {
  # Omarchy themes can select Yaru-gray, which the packaged yaru-icon-theme
  # does not ship. Qt gives up on a missing named theme before ever reaching
  # hicolor, so the tray renders a placeholder. Bridge the missing theme in
  # the desktop user's local icon directory.
  [[ ${ID:-} == omarchy ]] || return 0
  [[ -d /usr/share/icons/Yaru-gray ]] && return 0
  local shim_user=${SUDO_USER:-$(id -un)}
  if [[ $shim_user == root ]]; then
    echo 'note: skipping Yaru-gray tray bridge (re-run as the desktop user via sudo to apply it)' >&2
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

install_file() {
  local source=$1 destination=$2 mode=$3
  [[ -f $source ]] || fail "package is missing required file: $source"
  run_root install -D -m "$mode" "$source" "$destination"
}

assert_arch() {
  [[ -r /etc/os-release ]] || fail 'cannot identify the operating system'
  # Omarchy identifies itself as Arch through ID or ID_LIKE.
  . /etc/os-release
  [[ ${ID:-} == arch || " ${ID_LIKE:-} " == *' arch '* ]] ||
    fail 'this installer is for Arch Linux and Arch-based distributions (including Omarchy)'
  command -v pacman >/dev/null || fail 'pacman is required'
}

assert_unowned() {
  local path=$1
  [[ ! -e $path && ! -L $path ]] || fail "refusing to overwrite existing path: $path"
  # This explicit check keeps the failure understandable if a future path is a
  # dangling symlink or otherwise reported by pacman without existing on disk.
  ! pacman -Qo "$path" >/dev/null 2>&1 || fail "refusing to overwrite pacman-owned path: $path"
}

[[ -f $deb_file ]] || fail "package not found: $deb_file"
assert_arch

run_root pacman -S --needed --noconfirm binutils gtkmm3 gtk3 imagemagick libappindicator-gtk3 networkmanager socat
ar t "$deb_file" | grep -qx 'debian-binary' || fail 'the supplied file is not a Debian package'
[[ ! -e $manifest_path && ! -e $platform_path ]] || fail "an existing Minitela compatibility installation is recorded at $state_dir; uninstall it first"

stage_dir=$(mktemp -d)
manifest_tmp=$(mktemp)
desktop_tmp=$(mktemp)
cleanup() {
  rm -rf -- "$stage_dir"
  unlink "$manifest_tmp" 2>/dev/null || true
  unlink "$desktop_tmp" 2>/dev/null || true
}
trap cleanup EXIT

data_member=$(ar t "$deb_file" | awk '/^data\.tar\./ { print; exit }')
[[ -n $data_member ]] || fail 'the Debian package has no data archive'
case "$data_member" in
  *.tar.xz) tar_extract=(-xJf -) ;;
  *.tar.gz) tar_extract=(-xzf -) ;;
  *.tar.zst) tar_extract=(--zstd -xf -) ;;
  *.tar.bz2) tar_extract=(-xjf -) ;;
  *.tar) tar_extract=(-xf -) ;;
  *) fail "unsupported package data archive: $data_member" ;;
esac

# Do not restore package ownership, permissions, timestamps, ACLs, or xattrs.
ar p "$deb_file" "$data_member" |
  tar --no-same-owner --no-same-permissions --no-xattrs "${tar_extract[@]}" -C "$stage_dir"
[[ -x $stage_dir/usr/share/minitela/minitela ]] || fail 'the package does not contain the expected Minitela executable'

declare -a targets=(
  /usr/share/minitela
  /etc/udev/hwdb.d/72-keyboard.hwdb
  /etc/udev/rules.d/99-custom-input.rules
  /etc/udev/rules.d/99-ttyacm.rules
  /etc/xdg/autostart/minitela.desktop
  /usr/lib/systemd/system-sleep/minitela-controller
  /usr/share/applications/minitela.desktop
  /usr/share/glib-2.0/schemas/org.policorp.minitela.gschema.xml
  /usr/share/fonts/Inconsolata-VariableFont_wdth,wght.ttf
  /usr/share/fonts/Montserrat-VariableFont_wght.ttf
  /usr/share/icons/hicolor/256x256/apps/trayIcon.png
  /usr/local/bin/minitela-show
  /usr/local/bin/dpkg-query
  /usr/sbin/iwgetid
)
for target in "${targets[@]}"; do assert_unowned "$target"; done

run_root install -d -m 0755 /usr/share/minitela
tar --no-same-owner --no-same-permissions --no-xattrs -C "$stage_dir/usr/share/minitela" -cf - . |
  run_root tar --no-same-owner --no-same-permissions --no-xattrs -C /usr/share/minitela -xf -
run_root chmod 0755 /usr/share/minitela/minitela /usr/share/minitela/reset_infos/reset_infos.sh
run_root mv /usr/share/minitela/resources/MiniPanel-0.1.6.AppImage \
  /usr/share/minitela/resources/MiniPanel-0.1.6.AppImage.vendor
install_file "$repo_dir/scripts/common/minipanel-appimage-wrapper" /usr/share/minitela/resources/MiniPanel-0.1.6.AppImage 0755

install_file "$stage_dir/etc/udev/hwdb.d/72-keyboard.hwdb" /etc/udev/hwdb.d/72-keyboard.hwdb 0644
install_file "$stage_dir/etc/udev/rules.d/99-custom-input.rules" /etc/udev/rules.d/99-custom-input.rules 0644
install_file "$stage_dir/etc/udev/rules.d/99-ttyacm.rules" /etc/udev/rules.d/99-ttyacm.rules 0644
install_file "$stage_dir/etc/xdg/autostart/minitela.desktop" /etc/xdg/autostart/minitela.desktop 0644
install_file "$stage_dir/lib/systemd/system-sleep/minitela-controller" /usr/lib/systemd/system-sleep/minitela-controller 0755
install_file "$stage_dir/usr/share/glib-2.0/schemas/org.policorp.minitela.gschema.xml" /usr/share/glib-2.0/schemas/org.policorp.minitela.gschema.xml 0644
install_file "$stage_dir/usr/share/fonts/Inconsolata-VariableFont_wdth,wght.ttf" /usr/share/fonts/Inconsolata-VariableFont_wdth,wght.ttf 0644
install_file "$stage_dir/usr/share/fonts/Montserrat-VariableFont_wght.ttf" /usr/share/fonts/Montserrat-VariableFont_wght.ttf 0644
# The vendor tray icon is ICO data with a .png name, which icon-theme PNG
# loaders reject; decode it to a real PNG before registering it in hicolor.
tray_icon_src=/usr/share/minitela/resources/trayIcon.png
tray_icon_dest=/usr/share/icons/hicolor/256x256/apps/trayIcon.png
[[ -f $tray_icon_src ]] || fail 'package is missing required file: resources/trayIcon.png'
run_root install -d -m 0755 "$(dirname "$tray_icon_dest")"
run_root magick "ICO:$tray_icon_src[0]" -background none "PNG32:$tray_icon_dest"
run_root chmod 0644 "$tray_icon_dest"
install_omarchy_tray_bridge
install_file "$repo_dir/scripts/common/minitela-show" /usr/local/bin/minitela-show 0755
install_file "$repo_dir/scripts/common/dpkg-query" /usr/local/bin/dpkg-query 0755
install_file "$repo_dir/scripts/common/iwgetid" /usr/sbin/iwgetid 0755

cat >"$desktop_tmp" <<'DESKTOP'
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
install_file "$desktop_tmp" /usr/share/applications/minitela.desktop 0644

printf '%s\n' "${targets[@]}" >"$manifest_tmp"
run_root install -D -m 0600 "$manifest_tmp" "$manifest_path"
printf '%s\n' arch >"$desktop_tmp"
run_root install -m 0600 "$desktop_tmp" "$platform_path"
run_root glib-compile-schemas /usr/share/glib-2.0/schemas
run_root gtk-update-icon-cache -f /usr/share/icons/hicolor
run_root systemd-hwdb update
run_root udevadm control --reload
run_root udevadm trigger

echo 'Minitela installed safely. Open it from the application menu or run /usr/local/bin/minitela-show.'
