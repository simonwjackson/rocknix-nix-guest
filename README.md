# rocknix-nix-guest

NixOS guest flake and guest-side launch adapters for ROCKNIX SM8550/Thor main-space experiments.

This repo is the guest/runtime counterpart to [`nix-sm8550`](https://github.com/simonwjackson/nix-sm8550):

- this repo owns the NixOS container guest, profiles, session policy, and ROCKNIX `/storage` compatibility adapters;
- `nix-sm8550` owns package derivations such as Cemu;
- ROCKNIX remains the base OS, boot/recovery plane, and host-side nspawn importer/launcher.

## Layout

- `flake.nix` exposes aarch64 NixOS guest configurations and rootfs packages.
- `rocknix-guest.nix` is the stable default Layer 10b/12 SSH-capable guest import.
- `modules/` contains reusable NixOS modules for the container baseline, SSH, display, audio, network, tooling, and lid policy.
- `profiles/` composes modules into `minimal`, `ssh`, `main-space`, and `dev-env` profiles.
- `launchers/` contains guest/host helper scripts used by the Layer 14 main-space Cemu validation path.
- `scripts/static-checks.sh` is the repo-local structural check suite.

## Flake outputs

Configurations:

```sh
nix flake show --all-systems .
```

Expected NixOS configurations:

- `nixosConfigurations.rocknix-guest`
- `nixosConfigurations.rocknix-guest-main-space`
- `nixosConfigurations.rocknix-guest-dev-env`

Rootfs package outputs are exposed for `x86_64-linux` and `aarch64-linux` hosts:

```sh
nix build .#rootfs
sha256sum result/tarball/*.tar.*
```

The tarball is imported by ROCKNIX host tooling under the configured Layer 10 guest root, normally `/storage/machines/rocknix-guest`.

## Runtime boundaries

The guest artifact must remain:

- container-style (`boot.isContainer = true`), built for `aarch64-linux`;
- free of default passwords, shipped authorized keys, or password login;
- explicit about host binds and `/storage` compatibility state;
- independent from ROCKNIX `/usr`, `/flash`, `/boot`, and host `/etc` mutation;
- free of broad `/storage/.cache` binds;
- free of package derivations that belong in `nix-sm8550`.

Layer 14 main-space intentionally adds Sway, Mesa/Freedreno, PipeWire, NetworkManager, and Cemu launch adapters. The minimal/SSH profile remains the small lifecycle/SSH validation baseline.

## Cemu boundary

`rocknix-guest-main-space` consumes Cemu from the public package repo:

```nix
nix-sm8550.url = "github:simonwjackson/nix-sm8550";
environment.systemPackages = [ nix-sm8550.packages.${targetSystem}.cemu ];
```

`launchers/start_cemu_guest.sh` defaults to `/run/current-system/sw/bin/cemu` and may fall back to a promoted profile for live rollback. It delegates ROCKNIX `/storage` layout compatibility to `cemu-storage-adapter.sh`; Vulkan loader setup stays in the package wrapper from `nix-sm8550`.

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

## Relationship to ROCKNIX

This repo is meant to be consumed by ROCKNIX host integration after review/merge. Until then, ROCKNIX may still carry an in-tree copy of the guest for development and deployment bootstrapping.
