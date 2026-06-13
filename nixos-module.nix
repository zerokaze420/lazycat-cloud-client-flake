{ config, lib, pkgs, ... }:

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
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
      pkgs.zenity
    ];

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
