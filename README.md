# NixDaemonProxySwitchboard

NixOS module to run [ProxySwitchboard](https://github.com/yueyinqiu/ProxySwitchboard) as the proxy for `nix-daemon`. Packaging lives in the separate [`ProxySwitchboard-Nix`](https://github.com/yueyinqiu/ProxySwitchboard-Nix) repository.

## Adding as a flake input

```nix
{
  inputs = {
    nix-daemon-proxy-switchboard.url = "github:yueyinqiu/NixDaemonProxySwitchboard";
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

## Module

The module is exposed as `nixosModules.nix-daemon-proxy-switchboard` (also available as `nixosModules.default`):

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-daemon-proxy-switchboard.url = "github:yueyinqiu/NixDaemonProxySwitchboard";
  };

  outputs = { nixpkgs, nix-daemon-proxy-switchboard, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      modules = [
        nix-daemon-proxy-switchboard.nixosModules.nix-daemon-proxy-switchboard
        {
          services.nix-daemon-proxy-switchboard.enable = true;
        }
      ];
    };
  };
}
```

Options under `services.nix-daemon-proxy-switchboard`:

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `enable` | bool | `false` | Whether to run ProxySwitchboard as the proxy for `nix-daemon` |
| `packages.proxy-switchboard-server` | attrset | server (`install` default `false`) | The server package and whether to install it |
| `packages.proxy-switchboard-client` | attrset | client (`install` default `false`) | The bare client package and whether to install it |
| `packages.nix-daemon-proxy-client` | attrset | wrapper (`install` default `true`) | The client wrapper (a `nix-daemon-proxy` command) and whether to install it |
| `group` | str | `"nix-daemon-proxy"` | Group whose members can access the control socket |
| `controlSocket` | str | `"/run/nix-daemon-proxy/control.sock"` | Unix socket path the control HTTP server listens on |
| `proxyPort` | port | `62720` | TCP port the local proxy listens on (`127.0.0.1`) |

Each `packages.*` entry takes:

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `package` | package | from `ProxySwitchboard-Nix` (generated for `nix-daemon-proxy-client`) | The package to use |
| `install` | bool | `false` (`true` for `nix-daemon-proxy-client`) | Whether to add it to `environment.systemPackages` |

---

All documentation and `description` fields in this repository are AI-generated.