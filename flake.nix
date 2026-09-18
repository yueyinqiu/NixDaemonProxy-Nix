{
  description = "Nix packaging for NixDaemonProxy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          nix-daemon-proxy-client = pkgs.callPackage ./packages/client { };
          nix-daemon-proxy-server = pkgs.callPackage ./packages/server { };
        }
      );

      nixosModules = {
        nix-daemon-proxy = ./nixos-module;
        default = ./nixos-module;
      };
    };
}
