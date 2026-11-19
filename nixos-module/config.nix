{
  config,
  lib,
  pkgs,
}:
let
  cfg = config.services.nix-daemon-proxy-switchboard;

  runtimeDir = "/run/nix-daemon-proxy";
  controlSocket = "${runtimeDir}/control.sock";
  envFile = "${runtimeDir}/environment";
  dropInDir = "/run/systemd/system/nix-daemon.service.d";
  dropInFile = "${dropInDir}/nix-daemon-proxy.conf";

  proxyUrl = "http://user:\${password}@127.0.0.1:${toString cfg.proxyPort}/";

  initScript = pkgs.writeShellApplication {
    name = "nix-daemon-proxy-init";
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
      ${lib.getExe' pkgs.systemd "systemctl"} restart "nix-daemon"
    '';
  };

  cleanupScript = pkgs.writeShellApplication {
    name = "nix-daemon-proxy-cleanup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      rm -f "${dropInFile}"
      ${lib.getExe' pkgs.systemd "systemctl"} daemon-reload
      ${lib.getExe' pkgs.systemd "systemctl"} restart "nix-daemon"
    '';
  };
in
{
  users.groups.${cfg.group} = { };

  services.nix-daemon-proxy-switchboard.packages.nix-daemon-proxy-client.package = lib.mkDefault (pkgs.runCommand "nix-daemon-proxy" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe cfg.packages.proxy-switchboard-client.package} "$out/bin/nix-daemon-proxy" \
      --set-default PROXY_SWITCHBOARD_ARGUMENT_CONTROL_SOCKET ${lib.escapeShellArg controlSocket}
  '');

  environment.systemPackages =
    (lib.optional cfg.packages.proxy-switchboard-server.install cfg.packages.proxy-switchboard-server.package)
    ++ (lib.optional cfg.packages.proxy-switchboard-client.install cfg.packages.proxy-switchboard-client.package)
    ++ (lib.optional cfg.packages.nix-daemon-proxy-client.install cfg.packages.nix-daemon-proxy-client.package);

  systemd.services.nix-daemon-proxy-server = {
    description = "ProxySwitchboard (upstream for nix-daemon)";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      DynamicUser = true;
      Group = cfg.group;
      RuntimeDirectory = "nix-daemon-proxy";
      UMask = "0007";

      EnvironmentFile = envFile;

      ExecStartPre = [ "+${lib.getExe initScript}" ];
      ExecStart = ''
        ${lib.getExe cfg.packages.proxy-switchboard-server.package} \
          --control-socket ${controlSocket} \
          --proxy-port ${toString cfg.proxyPort}
      '';
      ExecStopPost = [ "+${lib.getExe cleanupScript}" ];

      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}