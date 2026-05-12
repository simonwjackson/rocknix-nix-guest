# rocknix-nix-guest

NixOS guest flake, emulator packages, and guest-side launch adapters for ROCKNIX SM8550 main-space experiments, with Odin 2/Thor as the validated default and Portal as an explicit device-profile target.

This repo owns the reviewed Nix surface for the SM8550 guest path:

- NixOS container guest profiles, modules, and rootfs outputs;
- package derivations for guest Cemu and guest-native Steam helpers;
- ROCKNIX `/storage` compatibility adapters and validation launchers.

ROCKNIX remains the base OS, boot/recovery plane, and host-side nspawn importer/launcher.

## Layout

- `flake.nix` exposes aarch64 NixOS guest configurations, rootfs packages, and emulator package outputs.
- `rocknix-guest.nix` is the stable default Layer 10b/12 SSH-capable guest import.
- `modules/` contains reusable NixOS modules for the container baseline, SM8550 device policy, SSH, display, audio, network, tooling, Steam, and lid policy.
- `profiles/` composes modules into `minimal`, `ssh`, `main-space`, and `dev-env` profiles; `profiles/devices/` holds small SM8550 per-device overrides.
- `packages/cemu/` contains the direct ROCKNIX-informed Cemu derivation, manifest, patches, and SM8550 default settings.
- `packages/steam/` contains guest-native Steam ARM64 bootstrap/seed/launch helpers, resources, and source manifest.
- `launchers/` contains guest/host helper scripts used by the Layer 14 main-space Cemu validation path.
- `scripts/static-checks.sh` is the repo-local structural check suite.

## Flake outputs

Configurations:

```sh
nix flake show --all-systems .
```

Expected NixOS configurations:

- `nixosConfigurations.rocknix-guest`
- `nixosConfigurations.rocknix-guest-main-space` (backward-compatible alias to Odin 2)
- `nixosConfigurations.rocknix-guest-main-space-odin2`
- `nixosConfigurations.rocknix-guest-main-space-portal`
- `nixosConfigurations.rocknix-guest-dev-env`

Rootfs package outputs are exposed for `x86_64-linux` and `aarch64-linux` hosts:

```sh
nix build .#rootfs          # alias to Odin 2 for current ROCKNIX packaging
nix build .#rootfs-odin2
nix build .#rootfs-portal
sha256sum result/tarball/*.tar.*
```

Emulator package outputs are also exposed for both systems:

```sh
nix build .#cemu --print-build-logs
nix build .#steam --print-build-logs
# equivalent Cemu compatibility surfaces:
nix build .#default
nix build .#cemu-rocknix-package
```

Current package outputs:

| Package | Purpose |
| --- | --- |
| `cemu` | Direct Cemu package replica of ROCKNIX `cemu-sa`, with package-owned `bin/cemu` wrapper. |
| `steam` | ROCKNIX-informed guest-native Steam ARM64 package helpers. |
| `default` | Alias to `cemu`. |
| `cemu-rocknix-package` | Transitional compatibility alias for existing ROCKNIX Layer 14 consumers. |
| `rootfs` | Layer 10b guest rootfs tarball imported by current ROCKNIX host tooling; aliases Odin 2. |
| `rootfs-odin2` | Odin 2/Thor main-space rootfs tarball. |
| `rootfs-portal` | Portal main-space rootfs tarball using the shared SM8550 defaults plus Portal profile overrides. |

The rootfs tarball is imported by ROCKNIX host tooling under the configured Layer 10 guest root, normally `/storage/machines/rocknix-guest`.

## Runtime boundaries

The guest artifact must remain:

- container-style (`boot.isContainer = true`), built for `aarch64-linux`;
- free of default passwords, shipped authorized keys, or password login;
- explicit about host binds and `/storage` compatibility state;
- independent from ROCKNIX `/usr`, `/flash`, `/boot`, and host `/etc` mutation;
- free of broad `/storage/.cache` binds.

Layer 14 main-space intentionally adds Sway, Mesa/Freedreno, PipeWire, NetworkManager, Cemu, Steam helpers, and launch adapters. The minimal/SSH profile remains the small lifecycle/SSH validation baseline.

## Package boundary

Packages own emulator-generic or package-generic setup:

- Nix Vulkan loader visibility in `packages/cemu`'s `bin/cemu` wrapper;
- SDL screensaver guard in `packages/cemu`'s `bin/cemu` wrapper;
- Cemu runtime data and SM8550 default settings under `$out/share/Cemu`;
- Steam ARM64 guest-native seed/launch helpers, bootstrap resources, and source evidence under `$out/share/steam-rocknix-bootstrap` and `$out/nix-support/rocknix-steam-bootstrap`;
- build evidence under `$out/nix-support/rocknix-cemu-build`.

Guest modules and launch adapters own device/session policy:

- ROCKNIX `/storage` compatibility layout;
- shared SM8550 defaults plus per-device overrides for display, input, audio UCM, and Cemu affinity;
- SM8550 host CPU/GPU tuning helpers;
- guest profile promotion/deploy scripts;
- BOTW/live validation orchestration;
- guest FHS/nix-ld loader policy, FEX rootfs management, Sway/Gamescope launch policy, and per-game Proton settings.

`rocknix-guest-main-space` installs the in-repo package outputs directly:

```nix
environment.systemPackages = [
  (packageSetFor targetSystem).cemu
  (packageSetFor targetSystem).steam
];
```

`launchers/start_cemu_guest.sh` defaults to `/run/current-system/sw/bin/cemu` and may fall back to a promoted profile for live rollback. It delegates ROCKNIX `/storage` layout compatibility to `cemu-storage-adapter.sh`; Vulkan loader setup stays in the Cemu package wrapper.

## Validation

Run local structural checks:

```sh
./scripts/static-checks.sh
```

Evaluate and dry-run the main-space closure:

```sh
nix flake show --all-systems --no-write-lock-file .
nix build --dry-run --no-write-lock-file .#nixosConfigurations.rocknix-guest-main-space.config.system.build.toplevel
```

Build package surfaces when package changes are in scope:

```sh
nix build .#cemu --print-build-logs
nix build .#steam --print-build-logs
```

## Relationship to ROCKNIX

This repo is meant to be consumed by ROCKNIX host integration after review/merge. Until then, ROCKNIX may still carry an in-tree copy of the guest for development and deployment bootstrapping.
