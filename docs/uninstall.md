# Uninstall: back to stock

v0.1 flashes nothing, so going back to stock means removing the boot hook and Musca's files from `/opt`. The stock
kernel, bootloader and system were never changed. Do this away from a scheduled meal (40 minutes either side, on your clock and the feeder's; it ends in a reboot).

## With the installer (coming with the installer)

`musca-install uninstall <device-ip>` runs the steps below, then checks stock is running. It needs the stock telnet
password (bundled with the installer).

## By hand

1. Get a shell on the device (SSH, or stock telnet / UART). Stock telnet needs the vendor password and UART does not; where to
   find the password and the UART login: [install guide](install.md#path-b-manual).
2. Remove the hook and shipped files. From the unpacked package:
   ```
   sh uninstall.sh            # keeps config, keys, Wi-Fi copy, logs and other user data
   sh uninstall.sh --purge    # also deletes /opt/musca, including config and keys
   ```
   Without the package: `rm /opt/system_init.sh` removes the hook (the quick path `touch /opt/musca/DISABLE` also works
   and keeps everything for a later retry). Until the reboot (step 3) the running supervisor keeps respawning `muscad`.
3. Reboot right after `uninstall.sh` (the running supervisor would otherwise try to respawn the deleted `muscad`, which can
   trigger a harmless but confusing stock fallback). If you turned telnet off or rotated the root password you need no extra
   step: after the reboot the stock start-up brings telnet and the vendor password back. Only if you want telnet back before
   the reboot, run `/opt/musca/musca-harden stock` from an SSH session **before** `uninstall.sh`.

## Verify you are on stock

After about two minutes, over stock telnet or UART:

```
ls /opt/system_init.sh        # must be absent ("No such file")
pidof ctrl                     # vendor controller running
pidof muscad supervisor        # must print nothing
grep -o 'kernel=.' /proc/cmdline   # kernel=a is the stock slot; uname -r shows the stock kernel version
```

The feeder should also appear in the vendor app again if you re-enable internet access for it. Stock keeps the vendor's
well-known telnet password, so keep the feeder on a network you control. Re-pairing in the vendor app may be needed;
this was not tested.

Musca never changed the feeder's own meal plan, but stock may re-sync it from the vendor cloud once the feeder has internet access again, so confirm that the next scheduled meal is dispensed.

## Reinstalling later

Install again from the [install guide](install.md); a purge needs a fresh config, a plain uninstall keeps yours.

A plain uninstall leaves the `/opt/musca` directory with your config, the **Wi-Fi copy** (`wpa_supplicant.conf`, which holds your
Wi-Fi password), SSH keys and host key, the telnet-off marker, logs and `config.web.toml`. A later reinstall therefore keeps
telnet off (when SSH starts). If you do not want that data left on the device, use `--purge` (or `rm -rf /opt/musca` once back
on stock).
