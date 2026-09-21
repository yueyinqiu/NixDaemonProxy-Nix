{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nix-daemon-proxy;
  client = pkgs.callPackage ../packages/client { };
in
{
  options.services.nix-daemon-proxy = {
    enable = lib.mkEnableOption "NixDaemonProxy";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../packages/server { };
      description = "The NixDaemonProxy server package to run.";
    };

    installClient = lib.mkEnableOption "the wrapped NixDaemonProxy client in `environment.systemPackages`";

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

    environment.systemPackages = lib.mkIf cfg.installClient [
      (pkgs.writeShellApplication {
        name = "nix-daemon-proxy";
        text = ''
          exec ${client}/bin/NixDaemonProxy.Client "$@" --control-socket ${lib.escapeShellArg cfg.controlSocket}
        '';
      })
    ];

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
            "--control-socket"
            cfg.controlSocket
            "--control-group"
            cfg.group
          ]
          ++ (
            if cfg.nixDaemonService == null then
              [ "--nix-daemon-service" ]
            else
              [
                "--nix-daemon-service"
                cfg.nixDaemonService
              ]
          )
          ++ lib.optionals (cfg.proxyPort != null) [
            "--proxy-port"
            (toString cfg.proxyPort)
          ]
        );

        ExecStartPre = ''"${pkgs.coreutils}/bin/rm" -f ${lib.escapeShellArg cfg.controlSocket}'';

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
