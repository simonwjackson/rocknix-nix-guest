{
  description = "ROCKNIX SM8550 NixOS guest rootfs and emulator packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # ROCKNIX Cemu is built against classic SDL2. nixos-25.11 aliases SDL2
    # to sdl2-compat, so keep a narrow 24.11 input only for that build input.
    nixpkgs-sdl2-classic.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs, nixpkgs-sdl2-classic }:
    let
      targetSystem = "aarch64-linux";
      hostSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllHostSystems = nixpkgs.lib.genAttrs hostSystems;
      packageSetFor = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgsSdl2Classic = nixpkgs-sdl2-classic.legacyPackages.${system};
          cemu = pkgs.callPackage ./packages/cemu/package.nix {
            SDL2_classic = pkgsSdl2Classic.SDL2;
          };
          steam = pkgs.callPackage ./packages/steam/package.nix { };
          ayn-odin2-ucm = pkgs.callPackage ./packages/audio/ayn-odin2-ucm { };
        in
        {
          default = cemu;
          cemu = cemu;
          steam = steam;
          ayn-odin2-ucm = ayn-odin2-ucm;
          # Compatibility alias for existing ROCKNIX Layer 14 scripts/docs.
          cemu-rocknix-package = cemu;
        };
      configuration = nixpkgs.lib.nixosSystem {
        system = targetSystem;
        modules = [ ./rocknix-guest.nix ];
      };
      mainSpaceConfigurationFor = deviceProfile: nixpkgs.lib.nixosSystem {
        system = targetSystem;
        modules = [
          ./profiles/main-space.nix
          deviceProfile
          ({ ... }: {
            # Keep the emulator package source of truth in this guest flake so
            # profile composition, package derivations, and launch adapters are
            # reviewed and versioned together.
            environment.systemPackages = [
              (packageSetFor targetSystem).cemu
              (packageSetFor targetSystem).steam
              (packageSetFor targetSystem).ayn-odin2-ucm
            ];
          })
        ];
      };
      mainSpaceOdin2Configuration = mainSpaceConfigurationFor ./profiles/devices/odin2.nix;
      mainSpacePortalConfiguration = mainSpaceConfigurationFor ./profiles/devices/portal.nix;
      # Backward-compatible alias: the production packaged rootfs remains the
      # hardware-validated Odin 2 / Thor profile until host packaging selects a
      # device-specific rootfs explicitly.
      mainSpaceConfiguration = mainSpaceOdin2Configuration;
      devEnvConfiguration = nixpkgs.lib.nixosSystem {
        system = targetSystem;
        modules = [ ./profiles/dev-env.nix ];
      };
      # The rootfs artifact is the production main-space guest: Sway,
      # guest-owned audio/input/display, and guest-native packages. The
      # minimal rocknix-guest configuration remains exposed for evaluation,
      # but the host autostart path must stage main-space or the device boots
      # to a container with no compositor.
      mkRootfs = hostSystem: configurationToPackage:
        let
          pkgs = import nixpkgs { system = hostSystem; };
          toplevel = configurationToPackage.config.system.build.toplevel;
          closure = pkgs.closureInfo {
            rootPaths = [ toplevel ];
          };
        in
        pkgs.runCommand "rocknix-layer10b-guest-rootfs"
          {
            nativeBuildInputs = [ pkgs.coreutils pkgs.gnutar pkgs.zstd ];
          } ''
          mkdir -p root/nix/store root/sbin root/usr/bin root/tmp root/proc root/sys root/dev root/run root/etc root/var root/var/lib $out/tarball
          chmod 1777 root/tmp
          while IFS= read -r store_path; do
            cp -a "$store_path" root/nix/store/
          done < ${closure}/store-paths
          ln -s ${toplevel}/init root/init
          ln -s ${toplevel}/init root/sbin/init
          ln -s /run/current-system/sw/bin/nix root/usr/bin/nix
          cp -a ${toplevel}/etc/. root/etc/
          chmod -R u+w root/etc
          if [ -e root/etc/static/ssh/sshd_config ]; then
            mkdir -p root/etc/ssh
            rm -f root/etc/ssh/sshd_config
            cp -L root/etc/static/ssh/sshd_config root/etc/ssh/sshd_config
            chmod u+w root/etc/ssh/sshd_config
          fi
          mkdir -p root/etc/ssh/authorized_keys.d
          rm -f root/etc/ssh/authorized_keys.d/root
          : > root/etc/ssh/authorized_keys.d/root
          chmod 600 root/etc/ssh/authorized_keys.d/root
          tar --sort=name --numeric-owner --owner=0 --group=0 --zstd \
            -cf $out/tarball/rocknix-layer10b-guest-rootfs-aarch64-linux.tar.zst \
            -C root .
        '';
    in
    {
      nixosConfigurations.rocknix-guest = configuration;
      nixosConfigurations.rocknix-guest-main-space = mainSpaceConfiguration;
      nixosConfigurations.rocknix-guest-main-space-odin2 = mainSpaceOdin2Configuration;
      nixosConfigurations.rocknix-guest-main-space-portal = mainSpacePortalConfiguration;
      nixosConfigurations.rocknix-guest-dev-env = devEnvConfiguration;
      packages = forAllHostSystems (hostSystem:
        let
          rootfsOdin2 = mkRootfs hostSystem mainSpaceOdin2Configuration;
          rootfsPortal = mkRootfs hostSystem mainSpacePortalConfiguration;
          rootfs = rootfsOdin2;
        in
        (packageSetFor hostSystem) // {
          inherit rootfs;
          "rootfs-odin2" = rootfsOdin2;
          "rootfs-portal" = rootfsPortal;
        });
      checks = forAllHostSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          static = pkgs.runCommand "rocknix-nix-guest-static-checks"
            {
              nativeBuildInputs = [ pkgs.shellcheck ];
            } ''
            cd ${self}
            ${pkgs.bash}/bin/bash scripts/static-checks.sh
            touch $out
          '';
        });
      formatter = forAllHostSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
    };
}
