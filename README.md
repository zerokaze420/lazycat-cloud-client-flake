# 懒猫微服 / LazyCat Cloud Client — Nix Flake

[![Nix Flake Check](https://img.shields.io/badge/flake-check-passing-brightgreen)](./flake.nix)
[![License](https://img.shields.io/badge/license-unfree-red)](./default.nix)
[![Platform](https://img.shields.io/badge/platform-x86__64--linux-blue)](./default.nix)

[懒猫微服](https://lazycat.cloud) 桌面客户端的 Nix flake — 个人云服务微服务器平台。

[English](./README.en.md)

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

## 安装方式对比

| 特性 | NixOS 模块 | Home Manager 模块 |
|------|-----------|------------------|
| 安装范围 | 系统级（所有用户） | 用户级（当前用户） |
| 网络管理（VPN/代理） | ✅ 完整支持 | ❌ 不支持 |
| CAP_NET_ADMIN 权限 | ✅ 自动配置 setuid wrapper | ❌ 无法管理 |
| Polkit 策略 | ✅ 自动安装 | ❌ 不涉及 |
| DBus 注册 | ✅ 自动注册 | ❌ 不涉及 |
| AppArmor 支持 | ✅ 可选宽松策略 | ❌ 不涉及 |
| 桌面入口 | ✅ 系统级 `.desktop` | ✅ 用户级 `.desktop` |
| 开机自启 | ❌ 需自行配置 | ✅ `autoStart` 选项 |
| 适用场景 | 多用户桌面 / 需要完整功能 | 个人桌面 / 配合 NixOS 模块使用 |

> **推荐**：在 NixOS 上**同时使用两个模块** — NixOS 模块处理系统级权限，Home Manager 模块管理用户级桌面集成和开机自启。非 NixOS 系统只能使用 Home Manager 模块（网络管理功能受限）。
>
> **为什么 Home Manager 无法支持 CAP_NET_ADMIN？** 授予 Linux capability 需要修改文件扩展属性（`setcap`），这必须由 root 执行，且 Nix Store 为只读文件系统。Home Manager 运行在用户级权限下，无法绕过这些约束。`security.wrappers` 是 NixOS 提供的一种系统级机制，通过在 `/run/wrappers/bin/` 创建 setuid wrapper 来委派权限 — 这只能在 NixOS 配置级别实现。

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
          nixpkgs.overlays = [
            lazycat-cloud-client.overlays.default  # 必需：使包在 pkgs 中可用
          ];
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
          nixpkgs.overlays = [
            lazycat-cloud-client.overlays.default  # 必需：使包在 pkgs 中可用
          ];
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

> **注意** Home Manager 模块**不处理** `CAP_NET_ADMIN` 权限。详见[安装方式对比](#安装方式对比)。

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

## 开发者指南

### 项目结构

```
├── flake.nix            # Flake 入口，定义 inputs/outputs
├── default.nix          # 包 derivation（下载 → 解压 → 修补 → 安装）
├── nixos-module.nix     # NixOS 系统级模块
├── hm-module.nix        # Home Manager 用户级模块
└── .github/
    └── workflows/
        └── ci.yml       # CI 流水线
```

### 更新版本

新版本发布时，修改 `default.nix` 中的两处：

1. `version` — 更新版本号
2. `hash` — 更新 SRI hash（可先用 `lib.fakeHash` 占位，让 Nix 报错给出正确值，再替换）

```bash
# 获取新版本 hash
nix-prefetch-url --unpack https://dl.lazycat.cloud/client/desktop/stable/lzc-client-desktop_v新版本.tar.zst
```

### 本地测试

```bash
# 快速求值检查
nix flake show

# 构建包（需 unfree）
nix build --impure

# 运行客户端
nix run . --impure

# 检查模块选项定义
nix eval .#nixosModules.default
```

### CI 流水线

每次 push/PR 到 `main` 分支（仅 `.nix` 文件变更时触发）：

| 阶段 | 触发条件 | 说明 |
|------|---------|------|
| `nix flake show` | push & PR | 轻量求值检查，秒级完成 |
| `nix flake check --impure` | 仅 PR | 模块选项类型校验 |

---

## 许可证

Nix derivation（[`default.nix`](./default.nix)）采用 MIT 许可证。  
打包的软件本身为专有软件，详见 [lazycat.cloud](https://lazycat.cloud)。
