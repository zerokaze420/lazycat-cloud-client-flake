{
  description = "LazyCat Cloud desktop client — a micro-server platform for personal cloud services";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    forAllSystems = nixpkgs.lib.genAttrs [
      "x86_64-linux"
    ];
  in
  {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      default = pkgs.callPackage ./default.nix { };
    });

    overlays.default = final: prev: {
      lazycat-cloud-client = final.callPackage ./default.nix { };
    };

    nixosModules.default = import ./nixos-module.nix;
    homeManagerModules.default = import ./hm-module.nix;
  };
}
