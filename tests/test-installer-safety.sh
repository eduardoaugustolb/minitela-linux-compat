#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
installer="$repo_dir/scripts/install-fedora.sh"
uninstaller="$repo_dir/scripts/uninstall-fedora.sh"
legacy_cleanup="$repo_dir/scripts/cleanup-legacy-fedora.sh"
repair="$repo_dir/scripts/repair-fedora.sh"
arch_installer="$repo_dir/scripts/install-arch.sh"
arch_uninstaller="$repo_dir/scripts/uninstall-arch.sh"
arch_repair="$repo_dir/scripts/repair-arch.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

bash -n "$installer" "$uninstaller" "$legacy_cleanup" "$repair" "$arch_installer" "$arch_uninstaller" "$arch_repair" "$repo_dir/scripts/dpkg-query"
sh -n "$repo_dir/scripts/minitela-show"

! rg -q 'cp[[:space:]]+-a|--archive' "$installer" || fail 'installer must not archive-copy into system directories'
rg -q 'mktemp -d -p /var/tmp' "$installer" || fail 'installer must use controlled /var/tmp staging'
rg -q -- '--no-xattrs' "$installer" || fail 'installer must suppress archive xattrs'
rg -q 'assert_context "\$path"' "$installer" || fail 'installer must verify top-level SELinux contexts'
rg -q 'manifest_path' "$installer" "$uninstaller" || fail 'install and uninstall must use an ownership manifest'
rg -q 'refusing to remove untracked files' "$uninstaller" || fail 'uninstaller must refuse unmanaged removal'
rg -q 'refusing to remove RPM-owned path' "$legacy_cleanup" || fail 'legacy cleanup must protect RPM-owned files'
rg -q 'refusing to remove changed legacy file' "$legacy_cleanup" || fail 'legacy cleanup must verify file contents'
rg -q 'manifest_path' "$repair" || fail 'repair must require an installation manifest'
rg -q 'pacman -S --needed --noconfirm' "$arch_installer" || fail 'Arch installer must install its declared dependencies through pacman'
rg -q 'gtkmm3' "$arch_installer" "$arch_repair" || fail 'Arch scripts must provide the gtkmm3 runtime required by Minitela'
rg -q 'assert_arch' "$arch_installer" || fail 'Arch installer must reject non-Arch systems'
rg -q 'refusing to overwrite pacman-owned path' "$arch_installer" || fail 'Arch installer must protect pacman-owned paths'
rg -q 'platform_path' "$arch_installer" "$arch_uninstaller" "$arch_repair" || fail 'Arch scripts must not operate on another installer platform'
rg -q 'exited before creating its control socket' "$repo_dir/scripts/minitela-show" || fail 'launcher must report an early application exit without waiting for the timeout'
"$repo_dir/scripts/dpkg-query" --showformat='${Version}' --show minitela | grep -qx '1.0.20' || fail 'dpkg-query shim must support the vendor invocation'
"$repo_dir/scripts/dpkg-query" --showformat= '${Version}' --show minitela | grep -qx '1.0.20' || fail 'dpkg-query shim must support the separated invocation'

echo 'Installer safety checks passed.'
