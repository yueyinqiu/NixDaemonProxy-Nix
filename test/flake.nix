{
  description = "NixDaemonProxySwitchboard tests";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    proxy-switchboard.url = "github:yueyinqiu/ProxySwitchboard-Nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      proxy-switchboard,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      module = import ../nixos-module { inherit proxy-switchboard; };
    in
    {
      checks.${system}.default = pkgs.testers.runNixOSTest {
        name = "nix-daemon-proxy-switchboard";

        nodes.machine =
          { ... }:
          {
            imports = [ module ];

            services.nix-daemon-proxy-switchboard.enable = true;

            # a group member used to verify socket access vs. password confidentiality
            users.users.alice = {
              isNormalUser = true;
              extraGroups = [ "nix-daemon-proxy" ];
            };
          };

        testScript = builtins.readFile ./test-script.py;
      };
    };
}