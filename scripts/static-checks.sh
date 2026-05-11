#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$ROOT/flake.nix" ] || fail "missing flake.nix"
[ -f "$ROOT/flake.lock" ] || fail "missing flake.lock"
[ -f "$ROOT/rocknix-guest.nix" ] || fail "missing default guest config"
[ -d "$ROOT/modules" ] || fail "missing modules directory"
[ -d "$ROOT/profiles" ] || fail "missing profiles directory"
[ -d "$ROOT/launchers" ] || fail "missing launchers directory"
[ -d "$ROOT/packages" ] || fail "missing packages directory"

# Flake shape and package exposure.
grep -q 'targetSystem = "aarch64-linux"' "$ROOT/flake.nix" \
  || fail "guest flake must target aarch64-linux"
grep -q 'x86_64-linux' "$ROOT/flake.nix" \
  || fail "guest flake must expose x86_64 host build package"
grep -q 'nixos-25.11' "$ROOT/flake.nix" \
  || fail "guest flake must pin the nixpkgs release input"
grep -q 'nixpkgs-sdl2-classic.url = "github:NixOS/nixpkgs/nixos-24.11"' "$ROOT/flake.nix" \
  || fail "Cemu package must retain narrow classic SDL2 input"
grep -q 'cemu = pkgs.callPackage ./packages/cemu/package.nix' "$ROOT/flake.nix" \
  || fail "root flake must expose packages.cemu from packages/cemu"
grep -q 'steam = pkgs.callPackage ./packages/steam/package.nix' "$ROOT/flake.nix" \
  || fail "root flake must expose packages.steam from packages/steam"
grep -q 'default = cemu' "$ROOT/flake.nix" \
  || fail "default package must alias cemu"
grep -q 'cemu-rocknix-package = cemu' "$ROOT/flake.nix" \
  || fail "compatibility alias must remain available for current consumers"
grep -q '(packageSetFor targetSystem).cemu' "$ROOT/flake.nix" \
  || fail "main-space guest must install in-repo Cemu package"
grep -q '(packageSetFor targetSystem).steam' "$ROOT/flake.nix" \
  || fail "main-space guest must install in-repo Steam package helpers"
old_package_repo="nix-sm${SM8550_SUFFIX:-8550}"
! grep -R "github:simonwjackson/$old_package_repo\|nix.registry.$old_package_repo\|$old_package_repo.packages" \
  "$ROOT/flake.nix" "$ROOT/flake.lock" "$ROOT/README.md" "$ROOT/launchers" >/tmp/rocknix-nix-guest-old-package-repo-grep.$$ \
  || { cat /tmp/rocknix-nix-guest-old-package-repo-grep.$$ >&2; rm -f /tmp/rocknix-nix-guest-old-package-repo-grep.$$; fail "guest repo must not depend on the former external package flake"; }
rm -f /tmp/rocknix-nix-guest-old-package-repo-grep.$$
grep -q 'root/etc/ssh/authorized_keys.d/root' "$ROOT/flake.nix" \
  || fail "rootfs must provide regular authorized_keys target for StrictModes"
grep -q 'root/usr/bin/nix' "$ROOT/flake.nix" \
  || fail "rootfs must expose /usr/bin/nix for bridge/smoke contracts"

# Guest baseline.
grep -R -q 'boot.isContainer = true' "$ROOT" \
  || fail "guest must be a container-style rootfs"
grep -R -q 'services.openssh = {' "$ROOT" \
  || fail "guest must define locked-down OpenSSH"
grep -R -q 'ports = \[ 2222 \];' "$ROOT" \
  || fail "guest SSH must listen on Layer 12 default port 2222"
grep -q 'profiles/ssh.nix' "$ROOT/rocknix-guest.nix" \
  || fail "default guest config must import SSH-capable modular profile"

for f in \
  modules/base.nix \
  modules/tools.nix \
  modules/ssh.nix \
  modules/display.nix \
  modules/audio.nix \
  modules/network.nix \
  modules/lid.nix \
  modules/steam.nix \
  packages/cemu/package.nix \
  packages/cemu/manifest.nix \
  packages/cemu/settings.SM8550.xml \
  packages/steam/package.nix \
  packages/steam/manifest.nix \
  profiles/minimal.nix \
  profiles/ssh.nix \
  profiles/main-space.nix \
  profiles/dev-env.nix; do
  [ -f "$ROOT/$f" ] || fail "missing guest module/profile/package: $f"
done

grep -q 'programs.sway' "$ROOT/modules/display.nix" \
  || fail "display module must enable sway"
grep -q 'hardware.graphics' "$ROOT/modules/display.nix" \
  || fail "display module must enable hardware.graphics"
grep -q 'services.pipewire' "$ROOT/modules/audio.nix" \
  || fail "audio module must enable pipewire"
grep -q 'services.dbus' "$ROOT/modules/audio.nix" \
  || fail "audio module must enable D-Bus"
grep -q 'hardware.bluetooth' "$ROOT/modules/audio.nix" \
  || fail "audio module must enable bluetooth"
grep -q 'networking.networkmanager' "$ROOT/modules/network.nix" \
  || fail "network module must enable NetworkManager"
grep -q 'networking.nftables' "$ROOT/modules/network.nix" \
  || fail "network module must use nftables"
grep -q 'networking.resolvconf' "$ROOT/modules/network.nix" \
  || fail "network module must explicitly handle resolvconf"
grep -q 'time.timeZone' "$ROOT/profiles/main-space.nix" \
  || fail "main-space profile must set time.timeZone"
grep -q 'CEMU_BIOS_ROOT = "/storage/roms/bios/cemu"' "$ROOT/profiles/main-space.nix" \
  || fail "main-space session must own temporary Cemu BIOS compatibility root"
grep -q 'CEMU_AFFINITY_MASK = "0xF8"' "$ROOT/profiles/main-space.nix" \
  || fail "main-space session must own measured SM8550 Cemu affinity default"

# Launch adapters.
for launcher in \
  botw-guest.sh \
  cemu-sm8550-performance.sh \
  cemu-storage-adapter.sh \
  games-launcher.sh \
  host-tune.sh \
  launch-host-cemu-through-guest-display.sh \
  remote-cemu-build-fingerprint.sh \
  remote-cemu-cleanup.sh \
  remote-cemu-live-campaign.sh \
  remote-cemu-promote.sh \
  remote-cemu-runner.sh \
  remote-cemu-runtime-ab.sh \
  remote-cemu-single-run-validation.sh \
  start_cemu_guest.sh \
  start_cemu_guest_candidate.sh \
  start_cemu_guest_gamescope.sh \
  start_cemu_guest_mangohud.sh \
  start_cemu_guest_rocknixmesa.sh; do
  path="$ROOT/launchers/$launcher"
  [ -f "$path" ] || fail "missing launcher: $launcher"
  bash -n "$path" || fail "launcher has syntax errors: $launcher"
done

grep -q 'SYSTEM_CEMU=' "$ROOT/launchers/start_cemu_guest.sh" \
  || fail "start_cemu_guest.sh must default through the main-space system Cemu package"
grep -q 'PROMOTED_CEMU=' "$ROOT/launchers/start_cemu_guest.sh" \
  || fail "start_cemu_guest.sh must retain promoted Cemu fallback"
grep -q 'REQUESTED_CEMU=${CEMU_BIN:-$SYSTEM_CEMU}' "$ROOT/launchers/start_cemu_guest.sh" \
  || fail "start_cemu_guest.sh must preserve CEMU_BIN override over system Cemu"
! grep -q 'CEMU_VULKAN_LOADER_LIB_PATH\|LD_LIBRARY_PATH' "$ROOT/launchers/start_cemu_guest.sh" \
  || fail "start_cemu_guest.sh must not own Vulkan loader setup"
grep -q 'cemu-storage-adapter.sh' "$ROOT/launchers/start_cemu_guest.sh" \
  || fail "start_cemu_guest.sh must delegate Cemu /storage layout to cemu-storage-adapter.sh"
grep -q 'CEMU_DEFAULT_SETTINGS' "$ROOT/launchers/cemu-storage-adapter.sh" \
  || fail "cemu-storage-adapter.sh must own fresh-state settings seeding"
grep -q 'cemu-sm8550-performance.sh' "$ROOT/launchers/botw-guest.sh" \
  || fail "botw-guest.sh must delegate SM8550 performance policy"
! grep -q 'P3_MAX=\|GPU_MIN=\|taskset -p' "$ROOT/launchers/botw-guest.sh" \
  || fail "botw-guest.sh must not own CPU/GPU/affinity policy directly"
grep -q 'AFFINITY_MASK="${CEMU_AFFINITY_MASK:-0xF8}"' "$ROOT/launchers/cemu-sm8550-performance.sh" \
  || fail "cemu-sm8550-performance.sh must own default Cemu big-core affinity policy"
grep -q 'temporary host adapter' "$ROOT/launchers/host-tune.sh" \
  || fail "host-tune.sh must document temporary host-adapter status"

# Package contracts migrated from the former package-only repo.
grep -F -q 'exec "\$cemu_wrapper_dir/Cemu"' "$ROOT/packages/cemu/package.nix" \
  || fail "package wrapper must exec real Cemu binary"
grep -q 'vulkan_loader_lib_path=' "$ROOT/packages/cemu/package.nix" \
  || fail "package wrapper must own Vulkan loader path"
grep -q 'SDL_VIDEO_ALLOW_SCREENSAVER' "$ROOT/packages/cemu/package.nix" \
  || fail "package wrapper must own SDL screensaver guard"
grep -q 'ROCKNIX cemu-sa package contract' "$ROOT/packages/cemu/manifest.nix" \
  || fail "Cemu manifest must document ROCKNIX package contract source"

grep -q 'ROCKNIX Steam ARM64 guest-native package contract' "$ROOT/packages/steam/manifest.nix" \
  || fail "Steam manifest must document ROCKNIX package contract source"
grep -q 'rev = "[0-9a-f]\{40\}"' "$ROOT/packages/steam/manifest.nix" \
  || fail "Steam manifest must record pinned ROCKNIX source revision"
grep -q 'guest-native-steam-target=true' "$ROOT/packages/steam/package.nix" \
  || fail "Steam package evidence must target guest-native Steam"
grep -q 'host-steam-fallback=false' "$ROOT/packages/steam/package.nix" \
  || fail "Steam package must not fall back to host Steam"
grep -q 'immutable-nix-store-valve-arm64-seed-artifacts=false' "$ROOT/packages/steam/package.nix" \
  || fail "Steam v1 package must not claim immutable Nix-store Valve ARM64 seed artifacts"
grep -q 'steam-arm64-bootstrap' "$ROOT/packages/steam/package.nix" \
  || fail "Steam package must install bootstrap helper"
grep -q 'steam-arm64-seed' "$ROOT/packages/steam/package.nix" \
  || fail "Steam package must install ARM64 seed helper"
grep -q 'steam-guest-native' "$ROOT/packages/steam/package.nix" \
  || fail "Steam package must install guest-native launcher helper"
grep -q 'STEAM_HOME' "$ROOT/packages/steam/scripts/steam-arm64-bootstrap" \
  || fail "Steam bootstrap helper must require explicit STEAM_HOME"
grep -q 'STEAM_GAMES_ROOT' "$ROOT/packages/steam/scripts/steam-arm64-bootstrap" \
  || fail "Steam bootstrap helper must require explicit STEAM_GAMES_ROOT"
grep -q 'STEAM_DOT' "$ROOT/packages/steam/scripts/steam-arm64-bootstrap" \
  || fail "Steam bootstrap helper must require explicit STEAM_DOT"
grep -q -- '--dry-run' "$ROOT/packages/steam/scripts/steam-arm64-bootstrap" \
  || fail "Steam bootstrap helper must support dry-run mode"
grep -q 'STEAM_MANIFEST_URL' "$ROOT/packages/steam/scripts/steam-arm64-seed" \
  || fail "Steam seed helper must know the ARM64 client manifest endpoint"
grep -q 'steamrtarm64/steam' "$ROOT/packages/steam/scripts/steam-guest-native" \
  || fail "Steam guest-native helper must execute the ARM64 Steam client"
grep -q 'NIX_LD' "$ROOT/packages/steam/scripts/steam-guest-native" \
  || fail "Steam guest-native helper must preflight NixOS dynamic linker strategy"
for resource in compatibilitytool.vdf registry.vdf toolmanifest.vdf; do
  [ -f "$ROOT/packages/steam/resources/${resource}" ] \
    || fail "Steam resource missing: ${resource}"
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$ROOT/packages/steam/scripts/steam-arm64-bootstrap" \
    "$ROOT/packages/steam/scripts/steam-arm64-seed" \
    "$ROOT/packages/steam/scripts/steam-guest-native"
fi

! grep -R 'systemctl\|swaymsg\|FEXRootFSFetcher\|gamescope\|/storage' \
  "$ROOT/packages/steam/package.nix" "$ROOT/packages/steam/scripts" >/tmp/rocknix-nix-guest-steam-boundary-grep.$$ \
  || { cat /tmp/rocknix-nix-guest-steam-boundary-grep.$$ >&2; rm -f /tmp/rocknix-nix-guest-steam-boundary-grep.$$; fail "Steam package executable logic must not own ROCKNIX host/session/storage policy"; }
rm -f /tmp/rocknix-nix-guest-steam-boundary-grep.$$

grep -q 'packages/cemu' "$ROOT/README.md" \
  || fail "README must document in-repo Cemu package"
grep -q 'packages/steam' "$ROOT/README.md" \
  || fail "README must document in-repo Steam package"
grep -q 'free of default passwords' "$ROOT/README.md" \
  || fail "README must document credential boundary"

printf 'static checks passed\n'
