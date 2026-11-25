{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.lazycat-cloud-client;
in
{
  options.services.lazycat-cloud-client = {
    enable = lib.mkEnableOption "LazyCat Cloud desktop client";

    package = lib.mkPackageOption pkgs "lazycat-cloud-client" { };

    enableAppArmor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable an unconfined AppArmor profile for the LazyCat Cloud client.
        This is required on systems with AppArmor in enforcing mode.
      '';
    };

    configureFileChooserPortal = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Route XDG FileChooser portal requests to the GTK backend.  This keeps
        the client's local-sync directory picker working when another portal
        backend is selected by a broad default such as "*".
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Exposes the host GPU drivers through /run/opengl-driver.  Binary
    # Electron/Chromium applications must use the host driver rather than a
    # Mesa driver captured in the Nix store (especially on NVIDIA systems).
    hardware.graphics.enable = lib.mkDefault true;

    # The client mounts remote folders through its bundled rclone/FUSE
    # implementation.  Enable the user mount helpers and allow_other, which
    # is required when the mounted directory is opened by another process.
    programs.fuse = {
      enable = true;
      userAllowOther = true;
    };

    # Catlink and the managed remote desktop runtime are downloaded at runtime.
    # nix-ld runs their pristine ELF files without changing /proc/self/exe.
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc
        zlib
        openssl
        wayland
        libxcb
        libxkbcommon
        libglvnd
        libx11
        libxi
        libxfixes
        libxdamage
        libxrandr
        libxtst
        dbus
        alsa-lib
        libpulseaudio
        pipewire
        libGL
        libdrm
        mesa
        glib
        gtk3
        cairo
        pango
        at-spi2-atk
        gdk-pixbuf
        fontconfig
        freetype
        libva
        libvdpau
      ];
    };

    environment.systemPackages = [
      cfg.package
    ];

    xdg.portal = lib.mkIf cfg.configureFileChooserPortal {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common."org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };

    security.wrappers.lzc-core = {
      source = "${cfg.package}/lib/lzc-client-desktop/core/.lzc-core-wrapped";
      capabilities = "cap_net_admin+ep";
      owner = "root";
      group = "root";
      permissions = "0755";
    };

    security.apparmor.policies."lzc-client-desktop" = lib.mkIf cfg.enableAppArmor {
      profile = ''
        ${cfg.package}/bin/lzc-client-desktop flags=(unconfined) { }
      '';
    };

    services.dbus.packages = [ cfg.package ];
  };

  meta.maintainers = with lib.maintainers; [ ];
}
