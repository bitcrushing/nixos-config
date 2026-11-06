#!@runtimeShell@
# Run OpenCE from a writable copy of the release. The game writes config.toml
# and maps/ next to the executable, and its self-updater replaces the
# executable there; the store forbids both.
set -euo pipefail

export PATH="@launcherTools@${PATH:+:$PATH}"
export LD_LIBRARY_PATH="@launcherLibs@:/run/opengl-driver-32/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

data="${XDG_DATA_HOME:-$HOME/.local/share}/opence"
stamp="$data/.nix-version"

# Copy on first start, after a package update, or if the copy is missing.
if [ ! -x "$data/halo" ] || [ "$(cat "$stamp" 2>/dev/null || true)" != "@version@" ]; then
  mkdir -p "$data"
  cp -rfT "@out@/share/opence" "$data"
  chmod -R u+rwX "$data"
  printf '%s\n' "@version@" > "$stamp"
fi

cd "$data"
export LD_LIBRARY_PATH="$data${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec ./halo "$@"
