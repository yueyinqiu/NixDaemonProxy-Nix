{
  config,
  lib,
  pkgs,
}:
let
  cfg = config.services.nix-daemon-proxy-switchboard;

  runtimeDir = "/run/nix-daemon-proxy-switchboard";
  envFile = "${runtimeDir}/environment";
  dropInDir = "/run/systemd/system/${cfg.nixDaemonService}.service.d";
  dropInFile = "${dropInDir}/nix-daemon-proxy-switchboard.conf";

  proxyUrl = "http://user:\${password}@127.0.0.1:${toString cfg.proxyPort}/";

  initScript = pkgs.writeShellApplication {
    name = "nix-daemon-proxy-switchboard-init";
    runtimeInputs = [
      pkgs.openssl
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      umask 077
      password="$(${lib.getExe pkgs.openssl} rand -hex 16)"

      install -d -m 0750 "${runtimeDir}"
      printf 'PROXY_SWITCHBOARD_SERVER_ARGUMENT_PROXY_PASSWORD=%s\n' "$password" > "${envFile}"
      chmod 600 "${envFile}"

      install -d "${dropInDir}"
      cat > "${dropInFile}" <<EOF
      [Service]
      Environment="all_proxy=${proxyUrl}"
      Environment="http_proxy=${proxyUrl}"
      Environment="https_proxy=${proxyUrl}"
      Environment="ALL_PROXY=${proxyUrl}"
      Environment="HTTP_PROXY=${proxyUrl}"
      Environment="HTTPS_PROXY=${proxyUrl}"
      EOF

      ${lib.getExe' pkgs.systemd "systemctl"} daemon-reload
      ${lib.getExe' pkgs.systemd "systemctl"} restart "${cfg.nixDaemonService}"
    '';
  };

  cleanupScript = pkgs.writeShellApplication {
    name = "nix-daemon-proxy-switchboard-cleanup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      rm -f "${dropInFile}"
      ${lib.getExe' pkgs.systemd "systemctl"} daemon-reload
      ${lib.getExe' pkgs.systemd "systemctl"} restart "${cfg.nixDaemonService}"
    '';
  };
in
{
  users.groups.${cfg.group} = { };

  systemd.services.nix-daemon-proxy-switchboard = {
    description = "ProxySwitchboard (upstream for nix-daemon)";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      DynamicUser = true;
      Group = cfg.group;
      RuntimeDirectory = "nix-daemon-proxy-switchboard";
      UMask = "0007";

      EnvironmentFile = envFile;

      ExecStartPre = [ "+${lib.getExe initScript}" ];
      ExecStart = ''
        ${lib.getExe cfg.package} \
          --control-socket ${cfg.controlSocket} \
          --proxy-port ${toString cfg.proxyPort}
      '';
      ExecStopPost = [ "+${lib.getExe cleanupScript}" ];

      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}