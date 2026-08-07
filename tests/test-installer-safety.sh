#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
installer="$repo_dir/scripts/install-fedora.sh"
uninstaller="$repo_dir/scripts/uninstall-fedora.sh"
legacy_cleanup="$repo_dir/scripts/cleanup-legacy-fedora.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

bash -n "$installer" "$uninstaller" "$legacy_cleanup"

! rg -q 'cp[[:space:]]+-a|--archive' "$installer" || fail 'installer must not archive-copy into system directories'
rg -q 'mktemp -d -p /var/tmp' "$installer" || fail 'installer must use controlled /var/tmp staging'
rg -q -- '--no-xattrs' "$installer" || fail 'installer must suppress archive xattrs'
rg -q 'assert_context "\$path"' "$installer" || fail 'installer must verify top-level SELinux contexts'
rg -q 'manifest_path' "$installer" "$uninstaller" || fail 'install and uninstall must use an ownership manifest'
rg -q 'refusing to remove untracked files' "$uninstaller" || fail 'uninstaller must refuse unmanaged removal'
rg -q 'refusing to remove RPM-owned path' "$legacy_cleanup" || fail 'legacy cleanup must protect RPM-owned files'
rg -q 'refusing to remove changed legacy file' "$legacy_cleanup" || fail 'legacy cleanup must verify file contents'

echo 'Installer safety checks passed.'
