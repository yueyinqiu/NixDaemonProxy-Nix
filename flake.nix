{
  description = "NixOS module to run ProxySwitchboard as the proxy for nix-daemon";

  inputs = {
    proxy-switchboard.url = "github:yueyinqiu/ProxySwitchboard-Nix";
  };

  outputs =
    {
      self,
      proxy-switchboard,
      ...
    }:
    let
      module = import ./nixos-module { inherit proxy-switchboard; };
    in
    {
      nixosModules = {
        nix-daemon-proxy-switchboard = module;
        default = module;
      };
    };
}