#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || $1 != --apply ]]; then
  echo "Usage: $0 --apply /path/to/minitela_VERSION_amd64.deb" >&2
  exit 64
fi

deb_file=$2

if [[ $EUID -eq 0 ]]; then
  run_root() { "$@"; }
else
  run_root() { sudo "$@"; }
fi

fail() {
  echo "Error: $*" >&2
  exit 1
}

[[ -f $deb_file ]] || fail "package not found: $deb_file"
ar t "$deb_file" | grep -qx 'debian-binary' || fail 'the supplied file is not a Debian package'
case "$(getenforce 2>/dev/null || true)" in
  Enforcing|Permissive) ;;
  *) fail 'SELinux must be enabled before legacy cleanup' ;;
esac

stage_dir=$(run_root mktemp -d -p /var/tmp minitela-legacy-cleanup.XXXXXX)
trap 'run_root rm -rf -- "$stage_dir"' EXIT
data_member=$(ar t "$deb_file" | awk '/^data\.tar\.xz$/ { print; exit }')
[[ -n $data_member ]] || fail 'this migration supports data.tar.xz packages only'
run_root ar p "$deb_file" "$data_member" |
  run_root tar --no-same-owner --no-same-permissions --no-xattrs -xJf - -C "$stage_dir"

declare -a legacy_paths=(
  /etc/udev/hwdb.d/72-keyboard.hwdb
  /etc/udev/rules.d/99-custom-input.rules
  /etc/udev/rules.d/99-ttyacm.rules
)

for destination in "${legacy_paths[@]}"; do
  relative=${destination#/}
  source_file="$stage_dir/$relative"
  [[ -f $source_file ]] || fail "package is missing expected legacy file: $relative"
  [[ -e $destination ]] || continue
  rpm -qf "$destination" >/dev/null 2>&1 && fail "refusing to remove RPM-owned path: $destination"
  [[ $(sha256sum "$source_file" | awk '{print $1}') == $(sha256sum "$destination" | awk '{print $1}') ]] ||
    fail "refusing to remove changed legacy file: $destination"
done

for destination in "${legacy_paths[@]}"; do
  [[ -e $destination ]] || continue
  run_root rm -f -- "$destination"
  echo "Removed verified legacy file: $destination"
done

run_root systemd-hwdb update
run_root udevadm control --reload
run_root udevadm trigger

for path in /etc /etc/udev /etc/udev/hwdb.d /etc/udev/rules.d; do
  expected=$(matchpathcon -n "$path")
  actual=$(/usr/bin/ls -Zd "$path" | awk '{print $1}')
  [[ $actual == "$expected" ]] || fail "SELinux context mismatch after cleanup: $path"
done

echo 'Verified legacy cleanup completed. You can now run scripts/install-fedora.sh.'
