from datetime import timedelta

start_all()

machine.wait_for_unit("nix-daemon-proxy-server.service")
machine.wait_for_unit("nix-daemon.service")

# --- the group exists ---
machine.succeed("getent group nix-daemon-proxy")

# --- RuntimeDirectory: 0750, owned by the dynamic user, group nix-daemon-proxy ---
rdir = machine.succeed("stat -c '%a %U:%G' /run/nix-daemon-proxy/run").strip()
rmode, rowner = rdir.split(" ", 1)
assert rmode == "750", f"runtime dir mode = {rdir!r}, want 750"
assert rowner.split(":")[1] == "nix-daemon-proxy", f"runtime dir owner = {rdir!r}"

# --- secret file: only root can read it ---
env = machine.succeed("stat -c '%a %U:%G' /run/nix-daemon-proxy/secret").strip()
assert env == "600 root:root", f"secret perms = {env!r}, want 600 root:root"

# wait for the server to bind its control socket
machine.wait_until_succeeds("test -S /run/nix-daemon-proxy/run/control.sock", timeout=timedelta(seconds=30))

# --- control socket: group can read/write, others get nothing ---
sock = machine.succeed("stat -c '%a %G' /run/nix-daemon-proxy/run/control.sock").strip()
smode, sgroup = sock.split(" ", 1)
assert sgroup == "nix-daemon-proxy", f"socket group = {sock!r}"
assert smode[1] in "67", f"socket group bits = {smode!r}, want rw"
assert smode[2] == "0", f"socket other bits = {smode!r}, want none"

# --- drop-in for nix-daemon carries the proxy environment ---
dropin = machine.succeed("cat /run/systemd/system/nix-daemon.service.d/nix-daemon-proxy.conf")
assert "all_proxy=http://user:" in dropin, dropin
assert "127.0.0.1:62720" in dropin, dropin

# --- nix-daemon actually got the proxy environment ---
pid = machine.succeed("systemctl show -p MainPID --value nix-daemon.service").strip()
assert pid != "0", "nix-daemon is not running"
nixenv = machine.succeed(f"tr '\\0' '\\n' < /proc/{pid}/environ | grep -E '^(all_proxy|ALL_PROXY)='")
assert "all_proxy=http://user:" in nixenv, nixenv

# --- a group member can use the socket, but cannot read the password ---
machine.succeed("runuser -u alice -- nix-daemon-proxy status")
machine.fail("runuser -u alice -- cat /run/nix-daemon-proxy/secret")