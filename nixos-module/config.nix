{
  config,
  lib,
  pkgs,
}:
let
  cfg = config.services.nix-daemon-proxy-switchboard;

  runtimeDirectoryName = "nix-daemon-proxy";
  runtimeDirectory = "/run/${runtimeDirectoryName}";
  controlSocket = "${runtimeDirectory}/control.sock";
  passwordFile = "${runtimeDirectory}/password";

  dropInDirectory = "/run/systemd/system/nix-daemon.service.d";
  dropInFile = "${dropInDirectory}/nix-daemon-proxy.conf";

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

      password="$(openssl rand -hex 16)"
      uid="$(stat -c %u "${runtimeDirectory}")"
      printf '%s' "$password" > "${passwordFile}"
      chown "$uid" "${passwordFile}"

      install -d "${dropInDirectory}"
      cat > "${dropInFile}" <<EOF
      [Service]
      Environment="all_proxy=${proxyUrl}"
      Environment="http_proxy=${proxyUrl}"
      Environment="https_proxy=${proxyUrl}"
      Environment="ALL_PROXY=${proxyUrl}"
      Environment="HTTP_PROXY=${proxyUrl}"
      Environment="HTTPS_PROXY=${proxyUrl}"
      EOF

      systemctl daemon-reload
      systemctl restart nix-daemon
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
      systemctl daemon-reload
      systemctl restart nix-daemon
    '';
  };

  runScript = pkgs.writeShellApplication {
    name = "nix-daemon-proxy-run";
    runtimeInputs = [
      pkgs.coreutils
    ];
    text = ''
      PROXY_SWITCHBOARD_SERVER_ARGUMENT_PROXY_PASSWORD="$(cat ${passwordFile})" \
        exec ${lib.getExe cfg.packages.proxy-switchboard-server.package} \
          --control-socket ${controlSocket} \
          --proxy-port ${toString cfg.proxyPort}
    '';
  };
in
{
  users.groups.${cfg.group} = { };

  services.nix-daemon-proxy-switchboard.packages.nix-daemon-proxy-client.package = lib.mkDefault (
    pkgs.runCommand "nix-daemon-proxy" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
      mkdir -p "$out/bin"
      makeWrapper ${lib.getExe cfg.packages.proxy-switchboard-client.package} "$out/bin/nix-daemon-proxy" \
        --set-default PROXY_SWITCHBOARD_ARGUMENT_CONTROL_SOCKET ${lib.escapeShellArg controlSocket}
    ''
  );

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
      RuntimeDirectory = runtimeDirectoryName;
      RuntimeDirectoryMode = "0750";
      UMask = "0007";

      ExecStartPre = [ "+${lib.getExe initScript}" ];
      ExecStart = lib.getExe runScript;
      ExecStopPost = [ "+${lib.getExe cleanupScript}" ];

      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
