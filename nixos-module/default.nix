{ proxy-switchboard }:
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    (import ./options.nix {
      inherit lib pkgs proxy-switchboard;
    })
  ];

  config = lib.mkIf config.services.nix-daemon-proxy-switchboard.enable (
    import ./config.nix {
      inherit config lib pkgs;
    }
  );
}