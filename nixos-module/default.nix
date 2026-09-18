{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nix-daemon-proxy;
in
{
  options.services.nix-daemon-proxy = {
    enable = lib.mkEnableOption "NixDaemonProxy";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../packages/server { };
      description = "The NixDaemonProxy server package to run.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "nix-daemon-proxy";
      description = "Group whose members get read/write access to the control socket.";
    };

    controlSocket = lib.mkOption {
      type = lib.types.str;
      default = "/run/nix-daemon-proxy.sock";
      description = "Unix socket path the control HTTP server listens on.";
    };

    proxyPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "TCP port the local proxy listens on (`127.0.0.1`). Random when `null`.";
    };

    nixDaemonService = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "nix-daemon";
      description = "Name of the systemd service to configure. Set to `null` to disable daemon configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };

    systemd.services.nix-daemon-proxy-server = {
      wantedBy = [ "multi-user.target" ];

      path = [
        pkgs.coreutils
        pkgs.systemd
      ];

      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            "${cfg.package}/bin/NixDaemonProxy.Server"
            "--control-socket" cfg.controlSocket
            "--control-group" cfg.group
            "--nix-daemon-service" (if cfg.nixDaemonService == null then "" else cfg.nixDaemonService)
          ]
          ++ lib.optionals (cfg.proxyPort != null) [ "--proxy-port" (toString cfg.proxyPort) ]
        );

        # kestrel deletes the socket file on clean shutdown, but if the
        # process is killed (crash, OOM, ...) the stale socket remains and
        # blocks the next start with "address already in use".
        # clean it up before each start.
        ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${cfg.controlSocket}";

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
