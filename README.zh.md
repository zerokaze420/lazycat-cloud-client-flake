# 懒猫微服 / LazyCat Cloud Client

[![Nix Flake Check](https://img.shields.io/badge/flake-check-passing-brightgreen)](./flake.nix)
[![License](https://img.shields.io/badge/license-unfree-red)](./default.nix)
[![Platform](https://img.shields.io/badge/platform-x86__64--linux-blue)](./default.nix)

[懒猫微服](https://lazycat.cloud) 桌面客户端的 Nix flake — 个人云服务微服务器平台。

[English](./README.md)

---

## 快速开始

```bash
# 直接运行（一次性）
nix run github:zerokaze420/lazycat-cloud-client-flake --impure

# 安装到 profile
nix profile install github:zerokaze420/lazycat-cloud-client-flake --impure

# 临时 shell 中试用
nix shell github:zerokaze420/lazycat-cloud-client-flake --impure
```

> **注意** 由于此包使用 `unfree` 许可证，需要 `--impure` 参数。  
> 永久配置方法见 [非自由软件](#非自由软件)。

---

## 用法

### NixOS 模块

系统级安装，包含权限管理和可选的 AppArmor 支持。

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
            enableAppArmor = true;      # 可选：宽松 AppArmor 策略
            # package = pkgs.lazycat-cloud-client;  # 默认值，可覆写
          };
        })
      ];
    };
  };
}
```

**选项：**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `services.lazycat-cloud-client.enable` | `bool` | `false` | 启用模块 |
| `services.lazycat-cloud-client.package` | `package` | `pkgs.lazycat-cloud-client` | 覆写包 |
| `services.lazycat-cloud-client.enableAppArmor` | `bool` | `false` | 宽松 AppArmor 策略 |

模块会自动：
- 安装客户端和 `zenity`（GUI 弹窗依赖）
- 通过 `security.wrappers` 授予 `lzc-core` 的 `CAP_NET_ADMIN` 权限
- 安装网络管理的 polkit 策略
- （可选）添加宽松的 AppArmor 策略

### Home Manager 模块

用户级安装，包含桌面集成和开机自启。

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
            autoStart = true;           # 开机自启
            # package = pkgs.lazycat-cloud-client;
          };
        })
      ];
    };
  };
}
```

**选项：**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `programs.lazycat-cloud-client.enable` | `bool` | `false` | 启用模块 |
| `programs.lazycat-cloud-client.package` | `package` | `pkgs.lazycat-cloud-client` | 覆写包 |
| `programs.lazycat-cloud-client.autoStart` | `bool` | `false` | 登录后自动启动 |

模块会：
- 安装客户端和 `zenity` 到你的用户环境
- 在 `~/.local/share/applications/` 下创建 `.desktop` 入口
- （可选）注册 systemd 用户服务实现开机自启

> **注意** Home Manager 模块**不处理** `CAP_NET_ADMIN` 权限。  
> 在 NixOS 上请搭配 [NixOS 模块](#nixos-模块) 以获得完整功能。

### Overlay

将包加入你的 `pkgs` 作用域。

```nix
{
  nixpkgs.overlays = [
    lazycat-cloud-client.overlays.default
  ];
}
```

之后可通过 `pkgs.lazycat-cloud-client` 引用。

### 传统 nix-build

不使用 flake 的情况：

```bash
git clone https://github.com/zerokaze420/lazycat-cloud-client-flake
cd lazycat-cloud-client-flake
NIXPKGS_ALLOW_UNFREE=1 nix-build -E 'with import <nixpkgs> {}; callPackage ./default.nix {}'
```

---

## 非自由软件

此包使用 `unfree` 许可证。永久允许的方法：

**NixOS / nixos-rebuild：** 在 `configuration.nix` 中添加

```nix
{ nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "lazycat-cloud-client"
  ];
}
```

**Flake 用户（nix profile / nix shell / nix run）：**

```nix
# 添加到 ~/.config/nixpkgs/config.nix
{ allowUnfree = true; }
```

或带环境变量传递 `--impure`：

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run github:zerokaze420/lazycat-cloud-client-flake --impure
```

---

## 架构

| 架构 | 状态 |
|------|------|
| `x86_64-linux` | 支持 |
| `aarch64-linux` | 暂不支持（上游未提供 arm64 构建） |

---

## 许可证

Nix derivation（[`default.nix`](./default.nix)）采用 MIT 许可证。  
打包的软件本身为专有软件，详见 [lazycat.cloud](https://lazycat.cloud)。
