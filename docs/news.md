# News

Short status notes. The documentation pages are the reference; this page says what moved and when.
Everything here is work in progress on one device.

## 19 November 2026

- **Stock-fallback recovery tool.** A script now logs in to the stock start-up after a fallback, saves the boot
  counter and hook logs, and prints the fallback reason. For the boot-counter reason only, it can clear the counter,
  reboot and run the pre-flight checks; every other reason is left for you to fix by hand.
  See [Safety and recovery](safety-recovery.md).
- **Planned-reboot credit (next userland release, not released yet).** A reboot you start on purpose will no longer
  count towards the boot counter that triggers the fallback. The credit is limited, is consumed once, and
  unplanned boots always count. Details in [Safety and recovery](safety-recovery.md).
- **Fallback password wording.** After a fallback the login uses the rotated root password when a valid one is
  stored; only without it is it the vendor password, which is public. The documentation now says so and asks you
  to re-apply your hardening afterwards.
- **Watchdog driver fix.** The own kernel's watchdog driver now clears the interrupt-enable bit in its probe
  function, which the earlier start-up stage leaves set. The same fix is in the draft of the mainline watchdog driver
  series. That series has **not been sent** upstream yet.
- **NAND bring-up (kernel).** Still in progress. The bisection continues and the probe hang has been narrowed to
  the init step. No further detail yet.
- **Reproducible builds.** The recipes for the root filesystem and the kernel modules are merged. The double-build
  proof (build twice, compare hashes) is still pending, so neither is claimed reproducible yet.
- **Site.** Link colours are readable again in both colour schemes.
