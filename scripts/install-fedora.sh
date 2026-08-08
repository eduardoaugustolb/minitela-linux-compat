#!/usr/bin/env bash
set -euo pipefail

readonly state_dir=/var/lib/minitela-linux-compat
readonly manifest_path="$state_dir/manifest"

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

require_selinux() {
  local mode
  mode=$(getenforce 2>/dev/null || true)
  case "$mode" in
    Enforcing|Permissive) ;;
    *) fail "SELinux must be enabled before installation; current state: ${mode:-unknown}" ;;
  esac
}

install_file() {
  local source=$1 destination=$2 mode=$3
  [[ -f $source ]] || fail "package is missing required file: $source"
  run_root install -D -m "$mode" "$source" "$destination"
}

if [[ ! -f $deb_file ]]; then
  fail "package not found: $deb_file"
fi
if ! ar t "$deb_file" | grep -qx 'debian-binary'; then
  fail 'the supplied file is not a Debian package'
fi

require_selinux
for path in /etc /usr /usr/lib /usr/share; do
  assert_context "$path"
done

run_root dnf install -y binutils libayatana-appindicator-gtk3 policycoreutils socat
[[ ! -e $manifest_path ]] || fail "an existing Minitela compatibility installation is recorded at $manifest_path; uninstall it first"

# Never honour caller-controlled TMPDIR: its context may be a user label.
stage_dir=$(run_root mktemp -d -p /var/tmp minitela-linux-compat.XXXXXX)
manifest_tmp=$(mktemp)
desktop_tmp=$(mktemp)
cleanup() {
  run_root rm -rf -- "$stage_dir"
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

# Do not restore archive xattrs, ACLs, ownership, permissions, or timestamps.
run_root ar p "$deb_file" "$data_member" |
  run_root tar --no-same-owner --no-same-permissions --no-xattrs "${tar_extract[@]}" -C "$stage_dir"

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
  /usr/local/bin/minitela-show
  /usr/local/bin/dpkg-query
  /usr/sbin/iwgetid
)
for target in "${targets[@]}"; do
  [[ ! -e $target ]] || fail "refusing to overwrite existing path: $target"
done

# /usr/share/minitela is a new, project-owned directory. Top-level system
# directories are never used as recursive-copy destinations.
run_root install -d -m 0755 /usr/share/minitela
run_root tar --no-same-owner --no-same-permissions --no-xattrs \
  -C "$stage_dir/usr/share/minitela" -cf - . |
  run_root tar --no-same-owner --no-same-permissions --no-xattrs -C /usr/share/minitela -xf -
run_root chmod 0755 /usr/share/minitela/minitela /usr/share/minitela/reset_infos/reset_infos.sh
run_root mv /usr/share/minitela/resources/MiniPanel-0.1.6.AppImage \
  /usr/share/minitela/resources/MiniPanel-0.1.6.AppImage.vendor
install_file "$repo_dir/scripts/minipanel-appimage-wrapper" \
  /usr/share/minitela/resources/MiniPanel-0.1.6.AppImage 0755

install_file "$stage_dir/etc/udev/hwdb.d/72-keyboard.hwdb" /etc/udev/hwdb.d/72-keyboard.hwdb 0644
install_file "$stage_dir/etc/udev/rules.d/99-custom-input.rules" /etc/udev/rules.d/99-custom-input.rules 0644
install_file "$stage_dir/etc/udev/rules.d/99-ttyacm.rules" /etc/udev/rules.d/99-ttyacm.rules 0644
install_file "$stage_dir/etc/xdg/autostart/minitela.desktop" /etc/xdg/autostart/minitela.desktop 0644
install_file "$stage_dir/lib/systemd/system-sleep/minitela-controller" /usr/lib/systemd/system-sleep/minitela-controller 0755
install_file "$stage_dir/usr/share/glib-2.0/schemas/org.policorp.minitela.gschema.xml" /usr/share/glib-2.0/schemas/org.policorp.minitela.gschema.xml 0644
install_file "$stage_dir/usr/share/fonts/Inconsolata-VariableFont_wdth,wght.ttf" /usr/share/fonts/Inconsolata-VariableFont_wdth,wght.ttf 0644
install_file "$stage_dir/usr/share/fonts/Montserrat-VariableFont_wght.ttf" /usr/share/fonts/Montserrat-VariableFont_wght.ttf 0644

install_file "$repo_dir/scripts/minitela-show" /usr/local/bin/minitela-show 0755
install_file "$repo_dir/scripts/dpkg-query" /usr/local/bin/dpkg-query 0755
install_file "$repo_dir/scripts/iwgetid" /usr/sbin/iwgetid 0755

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

run_root restorecon -RFv /usr/share/minitela
run_root restorecon -v \
  /etc/udev/hwdb.d/72-keyboard.hwdb \
  /etc/udev/rules.d/99-custom-input.rules \
  /etc/udev/rules.d/99-ttyacm.rules \
  /etc/xdg/autostart/minitela.desktop \
  /usr/lib/systemd/system-sleep/minitela-controller \
  /usr/share/applications/minitela.desktop \
  /usr/share/glib-2.0/schemas/org.policorp.minitela.gschema.xml \
  /usr/share/fonts/Inconsolata-VariableFont_wdth,wght.ttf \
  /usr/share/fonts/Montserrat-VariableFont_wght.ttf \
  /usr/local/bin/minitela-show /usr/local/bin/dpkg-query /usr/sbin/iwgetid
run_root glib-compile-schemas /usr/share/glib-2.0/schemas
run_root systemd-hwdb update
run_root udevadm control --reload
run_root udevadm trigger

for path in /etc /usr /usr/lib /usr/share; do
  assert_context "$path"
done

echo 'Minitela installed safely. Open it from the application menu or run /usr/local/bin/minitela-show.'
