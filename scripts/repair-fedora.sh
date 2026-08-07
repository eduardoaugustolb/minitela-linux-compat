#!/usr/bin/env bash
set -euo pipefail

readonly state_dir=/var/lib/minitela-linux-compat
readonly manifest_path="$state_dir/manifest"

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

[[ -f $manifest_path ]] || fail "no managed Minitela installation manifest exists at $manifest_path"
grep -qx '/usr/local/bin/dpkg-query' "$manifest_path" || fail 'installed manifest does not own the dpkg-query compatibility shim'
[[ -x /usr/share/minitela/minitela ]] || fail 'Minitela executable is not installed'

# Update only a path recorded as owned by this installation. This avoids an
# ad-hoc system edit and gives users a repeatable repair workflow.
run_root install -m 0755 "$repo_dir/scripts/dpkg-query" /usr/local/bin/dpkg-query
run_root restorecon -v /usr/local/bin/dpkg-query

if /usr/local/bin/dpkg-query --showformat='${Version}' --show minitela | grep -qx '1.0.20'; then
  echo 'Minitela dpkg-query compatibility repair completed.'
else
  fail 'dpkg-query compatibility validation failed'
fi
