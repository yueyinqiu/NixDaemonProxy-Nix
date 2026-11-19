{
  lib,
  pkgs,
  proxy-switchboard,
}:
{
  options.services.nix-daemon-proxy-switchboard = {
    enable = lib.mkEnableOption "ProxySwitchboard as the proxy for nix-daemon";

    group = lib.mkOption {
      type = lib.types.str;
      default = "nix-daemon-proxy";
      description = "Group whose members get read/write access to the control socket.";
    };

    controlSocket = lib.mkOption {
      type = lib.types.str;
      default = "/run/nix-daemon-proxy/control.sock";
      description = "Unix socket path the control HTTP server listens on.";
    };

    proxyPort = lib.mkOption {
      type = lib.types.port;
      default = 62720;
      description = "TCP port the local proxy listens on (`127.0.0.1`).";
    };

    packages.proxy-switchboard-server = {
      package = lib.mkOption {
        type = lib.types.package;
        default = proxy-switchboard.packages.${pkgs.stdenv.hostPlatform.system}.proxy-switchboard-server;
        description = "The ProxySwitchboard server package to run.";
      };
      install = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to add the server package to `environment.systemPackages`.";
      };
    };

    packages.proxy-switchboard-client = {
      package = lib.mkOption {
        type = lib.types.package;
        default = proxy-switchboard.packages.${pkgs.stdenv.hostPlatform.system}.proxy-switchboard-client;
        description = "The bare ProxySwitchboard client package.";
      };
      install = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to add the client package to `environment.systemPackages`.";
      };
    };

    packages.nix-daemon-proxy-client = {
      package = lib.mkOption {
        type = lib.types.package;
        description = "The client wrapper package (a `nix-daemon-proxy` command with the control socket preset). Override to supply your own.";
      };
      install = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to add the client wrapper to `environment.systemPackages`.";
      };
    };
  };
}