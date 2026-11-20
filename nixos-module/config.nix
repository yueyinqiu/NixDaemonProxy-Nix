{
  config,
  lib,
  pkgs,
}:
let
  cfg = config.services.nix-daemon-proxy-switchboard;

  serviceDirectoryName = "nix-daemon-proxy";
  runtimeDirectoryName = "run";

  serviceDirectory = "/run/${serviceDirectoryName}";
  controlSocket = "${serviceDirectory}/${runtimeDirectoryName}/control.sock";
  environmentFile = "${serviceDirectory}/secret";

  dropInDirectory = "/run/systemd/system/nix-daemon.service.d";
  dropInFile = "${dropInDirectory}/nix-daemon-proxy.conf";

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
      install -d -m 0755 "${serviceDirectory}"
      printf 'PROXY_SWITCHBOARD_SERVER_ARGUMENT_PROXY_PASSWORD=%s\n' "$password" > "${environmentFile}"

      install -d "${dropInDirectory}"
      proxy="http://user:$password@127.0.0.1:${toString cfg.proxyPort}/"
      cat > "${dropInFile}" <<EOF
      [Service]
      Environment="all_proxy=$proxy"
      Environment="http_proxy=$proxy"
      Environment="https_proxy=$proxy"
      Environment="ALL_PROXY=$proxy"
      Environment="HTTP_PROXY=$proxy"
      Environment="HTTPS_PROXY=$proxy"
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
      rm -f "${dropInFile}" "${environmentFile}"
      systemctl daemon-reload
      systemctl restart nix-daemon
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

  systemd.services.nix-daemon-proxy-init = {
    description = "Prepare the proxy switchboard password and nix-daemon configuration";
    before = [ "nix-daemon-proxy-server.service" ];
    requiredBy = [ "nix-daemon-proxy-server.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe initScript;
    };
  };

  systemd.services.nix-daemon-proxy-server = {
    description = "ProxySwitchboard (upstream for nix-daemon)";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      DynamicUser = true;
      Group = cfg.group;

      RuntimeDirectory = "${serviceDirectoryName}/${runtimeDirectoryName}";
      RuntimeDirectoryMode = "0750";
      UMask = "0007";

      EnvironmentFile = environmentFile;

      ExecStart = ''
        ${lib.getExe cfg.packages.proxy-switchboard-server.package} \
          --control-socket ${controlSocket} \
          --proxy-port ${toString cfg.proxyPort}
      '';

      ExecStopPost = "+${lib.getExe cleanupScript}";

      Restart = "on-failure";
    };
  };
}
