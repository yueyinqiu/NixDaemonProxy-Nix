# NixDaemonProxy-Nix

Nix packaging for [NixDaemonProxy](https://github.com/yueyinqiu/NixDaemonProxy) — an on-the-fly switchable HTTP/HTTPS/SOCKS5 proxy for the Nix daemon.

## Adding as a flake input

```nix
{
  inputs = {
    nix-daemon-proxy.url = "github:yueyinqiu/NixDaemonProxy-Nix";
  };
}
```

> To avoid building from source, you can use the `yueyinqiu` Cachix binary cache:
>
> ```nix
> {
>   nix.settings.extra-substituters = [
>     "https://yueyinqiu.cachix.org"
>   ];
>   nix.settings.extra-trusted-public-keys = [
>     "yueyinqiu.cachix.org-1:iooLFYpS7e6KAU4+QM5Zoj6Tq76jRGo+kjeAbu8JxAc="
>   ];
> }
> ```

## Packages

Two packages are exposed:

| Package | Binary | Description |
| --- | --- | --- |
| `nix-daemon-proxy-server` | `NixDaemonProxy.Server` | The local proxy server that `nix-daemon` points at |
| `nix-daemon-proxy-client` | `NixDaemonProxy.Client` | CLI used to switch the upstream proxy at runtime |

```nix
nix-daemon-proxy.packages.${system}.nix-daemon-proxy-server
nix-daemon-proxy.packages.${system}.nix-daemon-proxy-client
```

Or try them directly from the CLI:

```console
$ nix shell github:yueyinqiu/NixDaemonProxy-Nix#nix-daemon-proxy-client
```

## NixOS module

A module is exposed as `nixosModules.nix-daemon-proxy` (also available as
`nixosModules.default`). It runs the proxy server as a `systemd` service and
creates the control group:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-daemon-proxy.url = "github:yueyinqiu/NixDaemonProxy-Nix";
  };

  outputs = { nixpkgs, nix-daemon-proxy, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-daemon-proxy.nixosModules.nix-daemon-proxy
        {
          services.nix-daemon-proxy.enable = true;
        }
      ];
    };
  };
}
```

Options under `services.nix-daemon-proxy`:

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `enable` | bool | `false` | Whether to enable NixDaemonProxy |
| `package` | package | this flake's `nix-daemon-proxy-server` | The server package to run |
| `clientPackage` | package | wrapped client | Wrapped client with the control socket preset |
| `installClient` | bool | `false` | Also install the wrapped client into `environment.systemPackages` |
| `group` | str | `"nix-daemon-proxy"` | Group whose members can access the control socket |
| `controlSocket` | str | `"/run/nix-daemon-proxy.sock"` | Unix socket path the control server listens on |
| `proxyPort` | nullOr port | `null` | TCP port the local proxy listens on (`127.0.0.1`); random when `null` |
| `nixDaemonService` | nullOr str | `"nix-daemon"` | systemd service to configure; `null` disables daemon configuration |

The proxy password is always generated randomly per boot by the server.

`clientPackage` wraps `NixDaemonProxy.Client` so the `--control-socket` flag is
already preset to `services.nix-daemon-proxy.controlSocket`, and exposes it as
the `nix-daemon-proxy` binary. Set `installClient = true` to put it on the
system-wide `PATH`, or use `clientPackage` in your own `home.packages`:

## Usage

See the [NixDaemonProxy README](https://github.com/yueyinqiu/NixDaemonProxy) for
how to use the client.

---

All documentation and `description` fields in this repository are AI-generated.
