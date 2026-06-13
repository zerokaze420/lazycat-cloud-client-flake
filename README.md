# LazyCat Cloud Client

[![Nix Flake Check](https://img.shields.io/badge/flake-check-passing-brightgreen)](./flake.nix)
[![License](https://img.shields.io/badge/license-unfree-red)](./default.nix)
[![Platform](https://img.shields.io/badge/platform-x86__64--linux-blue)](./default.nix)

Nix flake for the [LazyCat Cloud](https://lazycat.cloud) desktop client — a micro-server platform for personal cloud services.

[中文](./README.zh.md)

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

> **Note** The Home Manager module does **not** handle `CAP_NET_ADMIN` capabilities.  
> For full functionality, pair it with the [NixOS module](#nixos-module) on NixOS systems.

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

## License

The Nix derivation ([`default.nix`](./default.nix)) is MIT-licensed.  
The packaged software is proprietary — see [lazycat.cloud](https://lazycat.cloud) for terms.
