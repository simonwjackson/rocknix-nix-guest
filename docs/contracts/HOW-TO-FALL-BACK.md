# HOW TO FALL BACK

This file ships to `/flash/HOW-TO-FALL-BACK.md` on SM8550 images. It is
readable from a card reader on another machine without booting the device.

## What this image is

Default boot reaches `rocknix-graphical.target`, which starts the NixOS guest
(`rocknix-guest-v2.service`) as the main product space. The guest owns display,
audio, input, networking policy, Steam/Cemu launchers, and hardware-button
behavior.

ROCKNIX remains the recovery/update substrate. Recovery is explicit; the host no
longer automatically restarts the legacy UI if the guest crashes.

Identify the current boot mode:

```text
ssh root@thor 'systemctl get-default; systemctl is-active rocknix-guest-v2.service'
```

- `rocknix-graphical.target` + active guest → Nix main-space.
- `rocknix.target` or inactive guest after using a recovery toggle → ROCKNIX
  recovery.

## Symptoms of a guest failure

- Black screen for more than 30 seconds after boot.
- Lid open / power button does nothing visible.
- Display shows the boot splash and never advances.
- Host SSH works, but `rocknix-guest-v2.service` repeatedly fails.

If host SSH still works, use the SSH recovery path first. If SSH is unavailable,
use the card-reader flag path.

## Recovery with SSH

```text
ssh root@thor
touch /flash/rocknix.no-nspawn
reboot
```

The next boot routes to ROCKNIX recovery instead of Nix main-space.

## Recovery with card reader

1. Power off the device.
2. Mount the `/flash` partition on another machine.
3. Create the flag file:

   ```text
   touch /path/to/flash/rocknix.no-nspawn
   ```

4. Eject/reinstall the card or storage device.
5. Power on. Boot routes to ROCKNIX recovery.

The flag file is sticky and persists across reboots until removed.

## Recovery with one-boot cmdline

If the bootloader exposes a way to add kernel arguments, boot once with:

```text
rocknix.safe=1
```

That routes this boot to ROCKNIX recovery. The override clears on the next
normal reboot.

## Confirming recovery mode

```text
systemctl get-default                    # rocknix.target
systemctl is-active rocknix-guest-v2     # inactive or not started
systemctl status rocknix-recovery-toggle # shows which recovery trigger won
```

## Exiting recovery mode

```text
rm /flash/rocknix.no-nspawn
reboot
```

If you used `rocknix.safe=1`, exiting is automatic: reboot without that cmdline
argument.

## Guest update/promotion logs

Image updates install a packaged guest source under `/usr/lib/nix-integration/guest`.
`rocknix-guest-promote.service` applies that source to the persistent guest
rootfs at boot when revisions differ.

Useful checks:

```text
cat /usr/lib/nix-integration/guest-revision
cat /storage/machines/rocknix-guest/etc/rocknix-guest-revision
cat /storage/machines/rocknix-guest/etc/rocknix-guest-system-path
journalctl -b -u rocknix-guest-promote.service --no-pager
journalctl -b -u rocknix-guest-v2.service --no-pager
```

## Re-flashing

If recovery does not get you back to a working device, use the standard ROCKNIX
reflash/update flow. `/storage` holds ROMs, saves, configs, and the persistent
guest rootfs; a normal image update does not intentionally wipe it.
