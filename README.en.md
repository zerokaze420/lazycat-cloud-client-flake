# LazyCat Cloud Client — Nix Flake

[![Nix Flake Check](https://img.shields.io/badge/flake-check-passing-brightgreen)](./flake.nix)
[![License](https://img.shields.io/badge/license-unfree-red)](./default.nix)
[![Platform](https://img.shields.io/badge/platform-x86__64--linux-blue)](./default.nix)

Nix flake for the [LazyCat Cloud](https://lazycat.cloud) desktop client — a micro-server platform for personal cloud services.

[中文](./README.md)

---

## Quick Start

```bash
# Run directly (one-off)
nix run github:zerokaze420/lazycat-cloud-client-flake --impure

# Install to profile
nix profile install github:zerokaze420/lazycat-cloud-client-flake --impure

# Try in temporary shell
nix shell github:zerokaze420/lazycat-cloud-client-flake --impure
```

> **Note** `--impure` is required because this package has an `unfree` license.  
> See [Unfree Packages](#unfree-packages) for permanent configuration.

---

## Installation Comparison

| Feature | NixOS Module | Home Manager Module |
|---------|-------------|---------------------|
| Scope | System-wide (all users) | Per-user (current user) |
| Network management (VPN/proxy) | ✅ Full support | ❌ Not supported |
| CAP_NET_ADMIN capability | ✅ Auto-configured setuid wrapper | ❌ Cannot manage |
| Polkit policy | ✅ Auto-installed | ❌ Not involved |
| DBus registration | ✅ Auto-registered | ❌ Not involved |
| AppArmor support | ✅ Optional unconfined profile | ❌ Not involved |
| Desktop entry | ✅ System-level `.desktop` | ✅ User-level `.desktop` |
| Auto-start on login | ❌ Manual configuration needed | ✅ `autoStart` option |
| Use case | Multi-user desktop / full functionality | Personal desktop / pair with NixOS module |

> **Recommendation**: On NixOS, **use both modules together** — the NixOS module handles system-level permissions, while the Home Manager module manages user-level desktop integration and auto-start. Non-NixOS systems can only use the Home Manager module (network management will be limited).
>
> **Why can't Home Manager support CAP_NET_ADMIN?** Granting Linux capabilities requires modifying file extended attributes (`setcap`), which must be executed by root, and the Nix Store is a read-only file system. Home Manager operates at user-level privileges and cannot bypass these constraints. `security.wrappers` is a NixOS system-level mechanism that delegates permission via setuid wrappers in `/run/wrappers/bin/` — this can only be implemented at the NixOS configuration level.

---

## Usage

### NixOS Module

System-level installation with capability management and optional AppArmor support.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lazycat-cloud-client.url = "github:zerokaze420/lazycat-cloud-client-flake";
  };

  outputs = { self, nixpkgs, lazycat-cloud-client, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      modules = [
        lazycat-cloud-client.nixosModules.default
        ({ config, ... }: {
          nixpkgs.overlays = [
            lazycat-cloud-client.overlays.default  # required: makes package available in pkgs
          ];
          services.lazycat-cloud-client = {
            enable = true;
            enableAppArmor = true;      # optional: unconfined AppArmor policy
            # package = pkgs.lazycat-cloud-client;  # default, can override
          };
        })
      ];
    };
  };
}
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `services.lazycat-cloud-client.enable` | `bool` | `false` | Enable the module |
| `services.lazycat-cloud-client.package` | `package` | `pkgs.lazycat-cloud-client` | Override the package |
| `services.lazycat-cloud-client.enableAppArmor` | `bool` | `false` | Unconfined AppArmor profile |

The module automatically:
- Installs the client and `zenity` (GUI dialog dependency)
- Grants `CAP_NET_ADMIN` to `lzc-core` via `security.wrappers`
- Installs the polkit policy for network management
- Optionally adds an unconfined AppArmor profile

### Home Manager Module

Per-user installation with desktop integration and auto-start.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    lazycat-cloud-client.url = "github:zerokaze420/lazycat-cloud-client-flake";
  };

  outputs = { self, nixpkgs, home-manager, lazycat-cloud-client, ... }: {
    homeConfigurations.your-user = home-manager.lib.homeManagerConfiguration {
      modules = [
        lazycat-cloud-client.homeManagerModules.default
        ({ config, ... }: {
          nixpkgs.overlays = [
            lazycat-cloud-client.overlays.default  # required: makes package available in pkgs
          ];
          programs.lazycat-cloud-client = {
            enable = true;
            autoStart = true;           # start on login
            # package = pkgs.lazycat-cloud-client;
          };
        })
      ];
    };
  };
}
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `programs.lazycat-cloud-client.enable` | `bool` | `false` | Enable the module |
| `programs.lazycat-cloud-client.package` | `package` | `pkgs.lazycat-cloud-client` | Override the package |
| `programs.lazycat-cloud-client.autoStart` | `bool` | `false` | Auto-start on login |

The module will:
- Install the client and `zenity` into your user profile
- Add a `.desktop` entry under `~/.local/share/applications/`
- Optionally register a systemd user service for auto-start

> **Note** The Home Manager module does **not** handle `CAP_NET_ADMIN` capabilities. See [Installation Comparison](#installation-comparison) for details.

### Overlay

Add the package to your `pkgs` scope.

```nix
{
  nixpkgs.overlays = [
    lazycat-cloud-client.overlays.default
  ];
}
```

Then reference it as `pkgs.lazycat-cloud-client`.

### Classic nix-build

Without flakes:

```bash
git clone https://github.com/zerokaze420/lazycat-cloud-client-flake
cd lazycat-cloud-client-flake
NIXPKGS_ALLOW_UNFREE=1 nix-build -E 'with import <nixpkgs> {}; callPackage ./default.nix {}'
```

---

## Unfree Packages

This package has an `unfree` license. To allow it permanently:

**NixOS / nixos-rebuild:** add to `configuration.nix`

```nix
{ nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "lazycat-cloud-client"
  ];
}
```

**Flake users (nix profile / nix shell / nix run):**

```nix
# Add to ~/.config/nixpkgs/config.nix
{ allowUnfree = true; }
```

Or pass `--impure` with the environment variable set:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run github:zerokaze420/lazycat-cloud-client-flake --impure
```

---

## Architecture

| Architecture | Status |
|-------------|--------|
| `x86_64-linux` | Supported |
| `aarch64-linux` | Not yet (upstream does not provide arm64 builds) |

---

## Developer Guide

### Project Structure

```
├── flake.nix            # Flake entrypoint, defines inputs/outputs
├── default.nix          # Package derivation (download → unpack → patch → install)
├── nixos-module.nix     # NixOS system-level module
├── hm-module.nix        # Home Manager user-level module
└── .github/
    └── workflows/
        └── ci.yml       # CI pipeline
```

### Updating the Version

When a new version is released, modify two fields in `default.nix`:

1. `version` — update the version string
2. `hash` — update the SRI hash (use `lib.fakeHash` as a placeholder, let Nix error with the correct value, then replace)

```bash
# Get the new version hash
nix-prefetch-url --unpack https://dl.lazycat.cloud/client/desktop/stable/lzc-client-desktop_v{VERSION}.tar.zst
```

### Local Testing

```bash
# Quick evaluation check
nix flake show

# Build the package (requires unfree)
nix build --impure

# Run the client
nix run . --impure

# Verify module option definitions
nix eval .#nixosModules.default
```

### CI Pipeline

Triggered on push/PR to `main` (only when `.nix` files change):

| Stage | Trigger | Description |
|-------|---------|-------------|
| `nix flake show` | push & PR | Lightweight flake evaluation, completes in seconds |
| `nix flake check --impure` | PR only | Module option type validation |

### CAP_NET_ADMIN Implementation

The Nix Store is a read-only filesystem, so `setcap` cannot be used directly. This flake works around the limitation via the following mechanisms:

| Mechanism | Purpose | File |
|-----------|---------|------|
| `security.wrappers` | Creates a setuid wrapper (`/run/wrappers/bin/lzc-core`) that grants `CAP_NET_ADMIN` at runtime | `nixos-module.nix` |
| `lzc-core` script | The real binary is renamed to `.lzc-core-wrapped`; a same-named script routes calls to the setuid wrapper | `default.nix` |
| Fake `getcap` | The app checks capabilities via `getcap` on startup; a fake `getcap` always returns `cap_net_admin=ep`, bypassing the read-only limitation | `default.nix` |
| Fake `setcap` | `linux_setcap.sh` always returns 0; polkit policy is set to `yes` to skip password prompts | `default.nix` |

**Call chain**: App → `lzc-core` (script) → `/run/wrappers/bin/lzc-core` (setuid + CAP) → `.lzc-core-wrapped` (real binary)

---

## License

The Nix derivation ([`default.nix`](./default.nix)) is MIT-licensed.  
The packaged software is proprietary — see [lazycat.cloud](https://lazycat.cloud) for terms.
