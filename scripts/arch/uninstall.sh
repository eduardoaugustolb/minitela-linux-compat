#!/usr/bin/env bash
set -euo pipefail

readonly state_dir=/var/lib/minitela-linux-compat
readonly manifest_path="$state_dir/manifest"
readonly platform_path="$state_dir/platform"

if [[ $EUID -eq 0 ]]; then
  run_root() { "$@"; }
else
  run_root() { sudo "$@"; }
fi

fail() { echo "Error: $*" >&2; exit 1; }

[[ -f $manifest_path ]] || fail "no managed installation manifest exists at $manifest_path; refusing to remove untracked files"
[[ $(<"$platform_path") == arch ]] || fail 'this installation was not created by the Arch installer; use its matching uninstaller'

declare -A allowed=(
  [/usr/share/minitela]=directory
  [/etc/udev/hwdb.d/72-keyboard.hwdb]=file
  [/etc/udev/rules.d/99-custom-input.rules]=file
  [/etc/udev/rules.d/99-ttyacm.rules]=file
  [/etc/xdg/autostart/minitela.desktop]=file
  [/usr/lib/systemd/system-sleep/minitela-controller]=file
  [/usr/share/applications/minitela.desktop]=file
  [/usr/share/glib-2.0/schemas/org.policorp.minitela.gschema.xml]=file
  [/usr/share/fonts/Inconsolata-VariableFont_wdth,wght.ttf]=file
  [/usr/share/fonts/Montserrat-VariableFont_wght.ttf]=file
  [/usr/share/icons/hicolor/256x256/apps/trayIcon.png]=file
  [/usr/local/bin/minitela-show]=file
  [/usr/local/bin/dpkg-query]=file
  [/usr/sbin/iwgetid]=file
)

while IFS= read -r path; do
  [[ -n $path ]] || continue
  kind=${allowed[$path]-}
  [[ -n $kind ]] || fail "manifest contains a path outside the approved ownership set: $path"
  if [[ $kind == directory ]]; then run_root rm -rf -- "$path"; else run_root rm -f -- "$path"; fi
done <"$manifest_path"

run_root rm -f -- "$manifest_path"
run_root rm -f -- "$platform_path"
run_root rmdir "$state_dir" 2>/dev/null || true

# Remove the Omarchy Yaru-gray bridge, but only if this installation created
# it: the marker comment proves ownership, and rmdir only succeeds when the
# user added nothing else to the directory.
shim_user=${SUDO_USER:-$(id -un)}
if [[ $shim_user != root ]]; then
  shim_home=$(getent passwd "$shim_user" | cut -d: -f6 || true)
  shim_dir=${shim_home:+$shim_home/.local/share/icons/Yaru-gray}
  shim_index=${shim_dir:+$shim_dir/index.theme}
  if [[ -n ${shim_index:-} && -f $shim_index ]] &&
     run_root grep -qx '# managed by minitela-linux-compat: Yaru-gray compatibility bridge' "$shim_index"; then
    run_root rm -f -- "$shim_index"
    run_root rmdir -- "$shim_dir" 2>/dev/null || true
  fi
fi

run_root glib-compile-schemas /usr/share/glib-2.0/schemas
run_root gtk-update-icon-cache -f /usr/share/icons/hicolor
run_root systemd-hwdb update
run_root udevadm control --reload
run_root udevadm trigger
echo 'Managed Minitela compatibility installation removed safely.'
