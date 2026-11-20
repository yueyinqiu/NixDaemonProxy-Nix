# NixDaemonProxySwitchboard

Switch the proxy used by **nix-daemon** on the fly, without rebuilding your NixOS configuration or editing `/etc` by hand.

This is a NixOS module that runs [ProxySwitchboard](https://github.com/yueyinqiu/ProxySwitchboard) — a local HTTP proxy whose upstream can be switched at runtime — as `nix-daemon`'s proxy. `nix-daemon` keeps pointing at a fixed local address; *which* upstream it actually reaches is changed with a single client command.

## Why not just configure the proxy in NixOS?

- Every switch (different proxy, different credentials, back to direct) would mean editing config, rebuilding, and probably rebooting.
- A proxy is often **personal and private** (e.g. your own Clash/V2Ray with credentials), while the NixOS config is usually shared and admin-maintained — private details don't belong there.

So the NixOS side stays proxy-free and just runs a local proxy server. *Which* upstream to use is decided at runtime by any user in the `nix-daemon-proxy` group.

> **Caveat:** the *setting* is per-user, but the *effect* is global — there's only one `nix-daemon` per machine. While a proxy is active, other users building with that daemon go through it too. Unavoidable with a single shared daemon.

## How it works

The systemd service of `nix-daemon` always points at a **local proxy server** (`ProxySwitchboard.Server`). The local proxy is the *only* hop configured in the daemon's environment, so nothing has to be rewritten to switch proxies:

```
 nix-daemon
     │   http_proxy = http://user:password@127.0.0.1:<port>/
     ▼
 ┌──────────────────────────────────────────────┐
 │ ProxySwitchboard.Server (local proxy)        │
 │   listens on 127.0.0.1, Basic-auth protected │
 │   control socket (Unix domain socket)         │
 └──────────────────────────────────────────────┘
     │  upstream switchable at runtime
     ▼
 HTTP / SOCKS4 / SOCKS5 / direct  ──►  internet
```

The flow is:

1. An init one-shot service (as root) generates a random proxy password and writes a systemd **drop-in** for `nix-daemon.service` that sets `all_proxy`, `http_proxy` and `https_proxy` to the local proxy, then reloads and restarts `nix-daemon`.
2. The server runs as a **DynamicUser** with no root; it reads the password from the environment and listens on `127.0.0.1:<port>` plus a Unix control socket.
3. You run the **client** (the wrapped `nix-daemon-proxy` command), which talks to the control socket and tells the server which *upstream* to use (HTTP, SOCKS4 or SOCKS5).
4. The server switches its upstream, and everything `nix-daemon` does is proxied through the chosen upstream — instantly.
5. When the server stops, it removes the drop-in and restarts `nix-daemon` to restore direct access.

See the main [ProxySwitchboard README](https://github.com/yueyinqiu/ProxySwitchboard) for how the server and client behave; this module only wires them to nix-daemon. The default packages live in the separate [`ProxySwitchboard-Nix`](https://github.com/yueyinqiu/ProxySwitchboard-Nix) repository — each can be swapped out via its `packages.*.package` option.

## Installation

Add the module as a flake input and enable it:

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

### Module options

Options under `services.nix-daemon-proxy-switchboard`:

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `enable` | bool | `false` | Whether to run ProxySwitchboard as the proxy for `nix-daemon` |
| `group` | str | `"nix-daemon-proxy"` | Group whose members can access the control socket |
| `proxyPort` | port | `62720` | TCP port the local proxy listens on (`127.0.0.1`) |
| `packages.proxy-switchboard-server` | attrset | server (`install` default `false`) | The server package and whether to install it |
| `packages.proxy-switchboard-client` | attrset | client (`install` default `false`) | The bare client package and whether to install it |
| `packages.nix-daemon-proxy-client` | attrset | wrapper (`install` default `true`) | The wrapped client (a `nix-daemon-proxy` command) and whether to install it |

Each `packages.*` entry takes:

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `package` | package | from `ProxySwitchboard-Nix` (generated for `nix-daemon-proxy-client`) | The package to use |
| `install` | bool | `false` (`true` for `nix-daemon-proxy-client`) | Whether to add it to `environment.systemPackages` |

The proxy password is generated randomly by the init service on every start of the server.

## Usage

The module installs a wrapped client named `nix-daemon-proxy` with the control socket already preset. It talks to the server over the control socket, so **you must be a member of the `nix-daemon-proxy` group**:

```nix
users.users.<your-user>.extraGroups = [ "nix-daemon-proxy" ];
```

Then switch the upstream:

```sh
nix-daemon-proxy http   -H 127.0.0.1 -P 7890        # HTTP(S) proxy
nix-daemon-proxy socks5 -H 192.168.1.2 -P 1080     # SOCKS5 proxy
nix-daemon-proxy direct                            # back to direct access
nix-daemon-proxy status                            # show the current upstream
```

The full command set (`http`, `socks5`, `direct`, `from-json`, `status`) and their options are documented in the [ProxySwitchboard README](https://github.com/yueyinqiu/ProxySwitchboard#usage) — the same commands apply, just under the `nix-daemon-proxy` name (and without needing `--control-socket`, which is preset).

> **Security:** never pass a password on the command line — options like `-p` show up in `ps`. Use the `PROXY_SWITCHBOARD_ARGUMENT_PASSWORD` environment variable, or `from-json` (which reads credentials from stdin).

## Security model

- The local proxy binds `127.0.0.1` and requires Basic auth; only the server knows the random password.
- The proxy password and the `nix-daemon` drop-in (which contains it) are written root-only (`600`) under a runtime directory; the drop-in and password are removed when the server stops.
- Access to the control socket is restricted to the `nix-daemon-proxy` group — the socket and its directory only grant that group (no others), so only members can switch the upstream.
- The server itself runs as a `DynamicUser` with no root privileges; the privileged steps (generating the password, writing the drop-in, restarting `nix-daemon`) are done by a separate root one-shot service.

## Rescue: proxy switched but not working

This should be next to impossible, but just in case: the switch succeeded but the server crashed — and keeps crashing on restart. The control socket is gone and `nix-daemon` is pointed at a dead proxy, so you can't even rebuild NixOS.

The proxy only reaches `nix-daemon` through a runtime systemd **drop-in**, so stopping the server (which removes it) or removing it by hand restores direct access:

```sh
sudo systemctl stop nix-daemon-proxy-server
sudo rm -f /run/systemd/system/nix-daemon.service.d/nix-daemon-proxy.conf
sudo systemctl daemon-reload
sudo systemctl restart nix-daemon
```

## License

[MIT](LICENSE)

---

All documentation and `description` fields in this repository are AI-generated.