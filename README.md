# rocknix-nix-guest relocated

This repository is retired as an active source tree.

The guest source now lives in the Nix-on-Rocks product repo:

```text
../nix-on-rocks/guest/
https://github.com/simonwjackson/nix-on-rocks/tree/main/guest
```

Thor and Odin2Portal remain first-class SM8550 guest profiles there:

```sh
cd ../nix-on-rocks/guest
nix build .#rootfs-thor
nix build .#rootfs-odin2portal
```

Use `nix-on-rocks` for all new work:

| Work type | Destination |
| --- | --- |
| Guest flake, NixOS modules, rootfs packages | `nix-on-rocks/guest/` |
| Guest seed build/release automation | `nix-on-rocks/.github/workflows/build-rootfs-seed.yml` |
| SM8550 host substrate changes | `nix-on-rocks/patches/rocknix/` |
| Product docs, acceptance, contracts, ops | `nix-on-rocks/docs/` |

This repository is retained only as a relocation pointer while old links, historical tags, and accepted seed references age out. Do not add new source, workflows, or product documentation here.
