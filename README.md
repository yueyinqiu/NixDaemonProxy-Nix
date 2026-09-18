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

## Usage

See the [NixDaemonProxy README](https://github.com/yueyinqiu/NixDaemonProxy) for
how to set up the server (NixOS `systemd` service) and use the client.

---

All documentation and `description` fields in this repository are AI-generated.
