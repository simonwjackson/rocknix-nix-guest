# rocknix-nix-guest relocated

The guest source has moved into the Nix-on-Rocks product repo:

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

This repository is retained only as a relocation pointer while old links, tags, and accepted seed references age out.
