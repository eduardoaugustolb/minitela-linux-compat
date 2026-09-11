#!/usr/bin/env bash
set -euo pipefail

readonly state_dir=/var/lib/minitela-linux-compat
readonly manifest_path="$state_dir/manifest"

if [[ $EUID -eq 0 ]]; then
  run_root() { "$@"; }
else
  run_root() { sudo "$@"; }
fi

fail() {
  echo "Error: $*" >&2
  exit 1
}

assert_context() {
  local path=$1 expected actual
  expected=$(matchpathcon -n "$path") || fail "cannot determine expected SELinux context for $path"
  actual=$(/usr/bin/ls -Zd "$path" | awk '{print $1}') || fail "cannot read SELinux context for $path"
  [[ $actual == "$expected" ]] || fail "SELinux context mismatch for $path (actual: $actual; expected: $expected)"
}

case "$(getenforce 2>/dev/null || true)" in
  Enforcing|Permissive) ;;
  *) fail 'SELinux must be enabled before uninstalling so labels can be verified' ;;
esac
[[ -f $manifest_path ]] || fail "no managed installation manifest exists at $manifest_path; refusing to remove untracked files"

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
  [/usr/local/bin/minitela-show]=file
  [/usr/local/bin/dpkg-query]=file
  [/usr/sbin/iwgetid]=file
)

while IFS= read -r path; do
  [[ -n $path ]] || continue
  kind=${allowed[$path]-}
  [[ -n $kind ]] || fail "manifest contains a path outside the approved ownership set: $path"
  if [[ $kind == directory ]]; then
    run_root rm -rf -- "$path"
  else
    run_root rm -f -- "$path"
  fi
done <"$manifest_path"

run_root rm -f -- "$manifest_path"
run_root rmdir "$state_dir" 2>/dev/null || true
run_root glib-compile-schemas /usr/share/glib-2.0/schemas
run_root systemd-hwdb update
run_root udevadm control --reload
run_root udevadm trigger

for path in /etc /usr /usr/lib /usr/share; do
  assert_context "$path"
done

echo 'Managed Minitela compatibility installation removed safely.'
