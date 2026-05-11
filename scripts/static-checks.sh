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
[ ! -d "$ROOT/flakes/cemu" ] || fail "Cemu package derivation must stay in nix-sm8550, not this guest repo"

grep -q 'targetSystem = "aarch64-linux"' "$ROOT/flake.nix" \
  || fail "guest flake must target aarch64-linux"
grep -q 'x86_64-linux' "$ROOT/flake.nix" \
  || fail "guest flake must expose x86_64 host build package"
grep -q 'nixos-25.11' "$ROOT/flake.nix" \
  || fail "guest flake must pin the nixpkgs release input"
grep -q 'nix-sm8550.url = "github:simonwjackson/nix-sm8550"' "$ROOT/flake.nix" \
  || fail "main-space guest must consume public nix-sm8550 package repo"
grep -q 'nix.registry.nix-sm8550.flake = nix-sm8550' "$ROOT/flake.nix" \
  || fail "main-space guest must expose nix-sm8550 in the Nix registry"
grep -q 'nix-sm8550.packages.${targetSystem}.cemu' "$ROOT/flake.nix" \
  || fail "main-space guest must install Cemu from nix-sm8550"
grep -q 'root/etc/ssh/authorized_keys.d/root' "$ROOT/flake.nix" \
  || fail "rootfs must provide regular authorized_keys target for StrictModes"
grep -q 'root/usr/bin/nix' "$ROOT/flake.nix" \
  || fail "rootfs must expose /usr/bin/nix for bridge/smoke contracts"

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
  profiles/minimal.nix \
  profiles/ssh.nix \
  profiles/main-space.nix \
  profiles/dev-env.nix; do
  [ -f "$ROOT/$f" ] || fail "missing guest module/profile: $f"
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
grep -q 'rocknix-steam-ensure-uinput' "$ROOT/modules/steam.nix" \
  || fail "Steam module must repair guest /dev/uinput before Steam Input starts"
grep -q '/sys/devices/virtual/misc/uinput/dev' "$ROOT/modules/steam.nix" \
  || fail "Steam uinput prep must derive the device number from sysfs when available"
grep -q '/proc/misc' "$ROOT/modules/steam.nix" \
  || fail "Steam uinput prep must fall back to kernel misc device discovery"
! grep -q 'mknod /dev/uinput c 10 223' "$ROOT/modules/steam.nix" \
  || fail "Steam uinput prep must not hardcode the live Thor uinput device number"
grep -q 'PRESSURE_VESSEL_FILESYSTEMS_RW' "$ROOT/modules/steam.nix" \
  || fail "Steam module must expose uinput/input devices to pressure-vessel"
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

grep -q 'nix-sm8550' "$ROOT/README.md" \
  || fail "README must document nix-sm8550 package boundary"
grep -q 'free of default passwords' "$ROOT/README.md" \
  || fail "README must document credential boundary"

printf 'static checks passed\n'
