# Running checks

After changing the client package, build it and check that the core ELF starts:

```sh
NIXPKGS_ALLOW_UNFREE=1 nix build .#default --impure --no-link
pkg=$(NIXPKGS_ALLOW_UNFREE=1 nix eval .#default.outPath --impure --raw)
readelf -l "$pkg/lib/lzc-client-desktop/core/.lzc-core-wrapped"
"$pkg/lib/lzc-client-desktop/core/.lzc-core-wrapped" -h
```

The build runs the `-h` check in `installCheckPhase`. Both `readelf` and the
core command must exit successfully. After activating the package in NixOS,
start the user service and check its journal for `lzc-core` startup and for
`SIGSEGV`:

```sh
systemctl --user restart lzc-client-desktop.service
journalctl --user -u lzc-client-desktop.service -b --no-pager -n 120
```

The full core starts network services and may request a certificate. Use `-h`
for routine checks.

On 2026-11-11, the fix was built against the machine's installed nixpkgs at
`/nix/store/r11n5gilgy5yslmy08hzb890y10wgm1g-source`. The resulting core
had a valid ELF program header, passed `-h`, and stayed running for an eight
second smoke test with `-forceDisableOSTUN` before `timeout` stopped it.
