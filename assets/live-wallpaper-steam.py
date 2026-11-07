#!/usr/bin/env python3
"""Steam sign-in for the settings app's Workshop page: subscribe to and
unsubscribe from Wallpaper Engine wallpapers without leaving it.

Sign-in is Steam's QR login (scan and approve in the Steam mobile app). The
tokens it gives are kept in the login keyring (Secret Service, through
secret-tool; passed on stdin, never on a command line), sent only to
Steam's own servers over HTTPS and never printed or logged. Signing out
deletes them. Nothing else is stored.

    live-wallpaper-steam.py login            QR sign-in; JSON lines: {state: scan, qr, url} /
                                             {state: confirm} / {state: done, account} /
                                             {state: expired} / {state: error, error}
    live-wallpaper-steam.py status           {signedIn, account, expires (unix)}
    live-wallpaper-steam.py logout           forget the tokens
    live-wallpaper-steam.py subscribe ID     {ok} or {error, signin: true when signing in again is needed}
    live-wallpaper-steam.py unsubscribe ID
    live-wallpaper-steam.py download ID      download a Workshop item into the own library with
                                             DepotDownloader (no Steam client or Wallpaper Engine
                                             needed); JSON lines: {state: qr, qr} (first time:
                                             scan it) / {state: progress, percent} / {state: done,
                                             path} / {state: error, error}
    live-wallpaper-steam.py remove ID        delete a Workshop item from the own library
"""

import base64
import json
import os
import pty
import re
import select
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.steampowered.com"
APPID = "431960"
HEADERS = {
    "User-Agent": "Mozilla/5.0",
    "Accept": "application/json, text/plain, */*",
    "Origin": "https://steamcommunity.com",
    "Referer": "https://steamcommunity.com/",
}
KEYRING = ["service", "caelestia-steam", "kind", "workshop-session"]
DEPOT_KEYRING = ["service", "caelestia-steam", "kind", "depot-session"]
# Where DepotDownloader (.NET isolated storage) keeps its remembered session.
# It's only there while a download runs; at rest it's in the keyring.
DEPOT_STORE = os.path.expanduser("~/.local/share/IsolatedStorage")
LIBRARY = os.environ.get("LIVE_WALLPAPER_LIBRARY") or os.path.expanduser("~/.local/share/caelestia/wallpaper-engine")
# DepotDownloader's own LogonID: sharing the Steam client's would log it out
DEPOT_LOGINID = "48151623"


def out(**kw) -> None:
    print(json.dumps(kw), flush=True)


def post(method: str, fields: dict) -> dict:
    req = urllib.request.Request(f"{API}/{method}", data=urllib.parse.urlencode(fields).encode(), headers=HEADERS)
    with urllib.request.urlopen(req, timeout=20) as r:
        text = r.read().decode("utf-8", "replace")
    return json.loads(text).get("response", {}) if text.strip() else {}


def jwt(token: str) -> dict:
    try:
        part = token.split(".")[1]
        return json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))
    except (IndexError, ValueError):
        return {}


# ---- Keyring --------------------------------------------------------------

def load(attrs: list[str] = KEYRING) -> dict:
    try:
        r = subprocess.run(["secret-tool", "lookup", *attrs], capture_output=True, text=True, timeout=10)
        return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else {}
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return {}


def save(session: dict, attrs: list[str] = KEYRING, label: str = "Steam sign-in (Caelestia live wallpapers)") -> bool:
    try:
        r = subprocess.run(["secret-tool", "store", f"--label={label}", *attrs],
                           input=json.dumps(session), text=True, capture_output=True, timeout=10)
        return r.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def clear() -> None:
    subprocess.run(["secret-tool", "clear", *KEYRING], capture_output=True, timeout=10)
    subprocess.run(["secret-tool", "clear", *DEPOT_KEYRING], capture_output=True, timeout=10)
    shutil.rmtree(DEPOT_STORE, ignore_errors=True)
    try:
        os.remove(os.path.join(LIBRARY, ".depot-account"))
    except OSError:
        pass


def depot_restore() -> None:
    """DepotDownloader's session, from the keyring into its store (0700/0600)
    for the run."""
    files = load(DEPOT_KEYRING)
    for rel, data in files.items():
        path = os.path.normpath(os.path.join(DEPOT_STORE, rel))
        if not path.startswith(DEPOT_STORE + os.sep):
            continue
        os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "wb") as f:
            f.write(base64.b64decode(data))
    secure_depot_store()


def depot_stash() -> None:
    """After the run: its session back into the keyring, and off the disk
    (deleted even if the keyring refuses it: then the next download asks
    for the QR code again)."""
    files = {}
    for d, _, names in os.walk(DEPOT_STORE):
        for n in names:
            p = os.path.join(d, n)
            try:
                with open(p, "rb") as f:
                    files[os.path.relpath(p, DEPOT_STORE)] = base64.b64encode(f.read()).decode()
            except OSError:
                pass
    if files:
        save(files, DEPOT_KEYRING, "Steam download session (Caelestia live wallpapers)")
    shutil.rmtree(DEPOT_STORE, ignore_errors=True)


# ---- Sign-in ----------------------------------------------------------------

def qr_image(url: str) -> str:
    # Private runtime dir (0700): the picture only lives while signing in
    path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), f"caelestia-steam-qr-{os.getpid()}-{int(time.time() * 1000)}.png")
    subprocess.run(["qrencode", "-o", path, "-s", "10", "-m", "2", url], check=True, timeout=10)
    return path


def login() -> None:
    old = []
    try:
        begin = post("IAuthenticationService/BeginAuthSessionViaQR/v1/", {
            "input_json": json.dumps({"device_details": {"device_friendly_name": "Caelestia live wallpapers", "platform_type": 2}}),
        })
        client_id, request_id, url = str(begin["client_id"]), begin["request_id"], begin["challenge_url"]
        interval = float(begin.get("interval", 5) or 5)
        qr = qr_image(url)
        old.append(qr)
        out(state="scan", qr=qr, url=url)
        deadline = time.time() + 180
        confirming = False
        while time.time() < deadline:
            time.sleep(interval)
            r = post("IAuthenticationService/PollAuthSessionStatus/v1/", {"client_id": client_id, "request_id": request_id})
            if r.get("refresh_token"):
                refresh = r["refresh_token"]
                steamid = str(jwt(refresh).get("sub", ""))
                session = {"account": r.get("account_name", ""), "steamid": steamid, "access": r.get("access_token", ""), "refresh": refresh}
                if not steamid or not save(session):
                    out(state="error", error="Couldn't save the sign-in to the keyring")
                    return
                out(state="done", account=session["account"])
                return
            if r.get("new_client_id") and str(r["new_client_id"]) != "0":
                client_id = str(r["new_client_id"])
            if r.get("new_challenge_url") and r["new_challenge_url"] != url:
                url = r["new_challenge_url"]
                qr = qr_image(url)
                old.append(qr)
                out(state="scan", qr=qr, url=url)
            elif r.get("had_remote_interaction") and not confirming:
                confirming = True
                out(state="confirm")
        out(state="expired")
    except Exception as e:  # network, Steam refusing, qrencode missing
        out(state="error", error=str(e))
    finally:
        for p in old:
            try:
                os.remove(p)
            except OSError:
                pass


def access_token() -> tuple[str, str]:
    """A valid access token (refreshed when about to expire), or ("", reason)."""
    s = load()
    if not s.get("refresh"):
        return "", "Not signed in to Steam"
    if jwt(s["refresh"]).get("exp", 0) <= time.time() + 60:
        return "", "The Steam sign-in expired"
    if jwt(s.get("access", "")).get("exp", 0) > time.time() + 60:
        return s["access"], ""
    try:
        r = post("IAuthenticationService/GenerateAccessTokenForApp/v1/", {"refresh_token": s["refresh"], "steamid": s["steamid"]})
    except Exception as e:
        return "", f"Couldn't renew the Steam sign-in: {e}"
    if not r.get("access_token"):
        return "", "Steam didn't renew the sign-in"
    s["access"] = r["access_token"]
    if r.get("refresh_token"):  # Steam may rotate it
        s["refresh"] = r["refresh_token"]
    save(s)
    return s["access"], ""


def subscription(item: str, subscribe: bool) -> None:
    token, why = access_token()
    if not token:
        out(error=why, signin=True)
        return
    try:
        post(f"IPublishedFileService/{'Subscribe' if subscribe else 'Unsubscribe'}/v1/", {
            "access_token": token,
            "publishedfileid": item,
            "list_type": "1",
            "appid": APPID,
            "notify_client": "1",  # the running Steam client downloads it at once
        })
        out(ok=True)
    except urllib.error.HTTPError as e:
        out(error=f"Steam refused it (HTTP {e.code})", signin=e.code in (401, 403))
    except Exception as e:
        out(error=str(e))


# ---- Downloads (DepotDownloader) ------------------------------------------

def qr_from_text(lines: list[str]) -> str:
    """DepotDownloader draws its QR code with "██" per module: as a picture (PBM)."""
    rows = [[1 if line[i:i + 2] == "██" else 0 for i in range(0, len(line) - 1, 2)] for line in lines]
    width = max(len(r) for r in rows)
    path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), f"caelestia-depot-qr-{os.getpid()}.pbm")
    with open(path, "w") as f:
        f.write(f"P1\n{width} {len(rows)}\n")
        for r in rows:
            f.write(" ".join(str(v) for v in r + [0] * (width - len(r))) + "\n")
    return path


def download(item: str) -> None:
    # DepotDownloader remembers its own session (not the keyring's); this
    # marker (the account name, no secret) says it has one
    marker = os.path.join(LIBRARY, ".depot-account")
    try:
        account = open(marker).read().strip()
    except OSError:
        account = ""
    target = os.path.join(LIBRARY, "workshop", item)
    tmp = os.path.join(LIBRARY, ".downloading", item)
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp, exist_ok=True)
    cmd = ["depotdownloader", "-app", APPID, "-pubfile", item, "-dir", tmp, "-loginid", DEPOT_LOGINID, "-remember-password"]
    # Signed in once: DepotDownloader remembers the session under the account
    # name (its own file, see secure_depot_store); the first time, a QR code
    cmd += ["-username", account] if account else ["-qr"]
    asked_password = False
    if not shutil.which("depotdownloader"):
        out(state="error", error="DepotDownloader isn't installed")
        return
    depot_restore()
    pid, fd = pty.fork()  # a terminal: it draws the QR code only for one
    if pid == 0:
        os.execvp(cmd[0], cmd)
    qr_lines, in_qr, buf, qr_path, reaped = [], False, "", "", False
    ansi = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]")

    def show_qr():
        nonlocal in_qr, qr_path
        in_qr = False
        if qr_lines:
            qr_path = qr_from_text(qr_lines)
            out(state="qr", qr=qr_path)

    try:
        while True:
            r, _, _ = select.select([fd], [], [], 1.0)
            if not r:
                # Quiet after drawing the code: it waits for the scan
                if in_qr:
                    show_qr()
                continue
            try:
                chunk = os.read(fd, 4096).decode("utf-8", "replace")
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
            # Its remembered session is gone: it asks for the password (no
            # newline after the prompt). Stop; signing in again uses the QR code.
            if account and re.search(r"(?i)password", buf):
                asked_password = True
                break
            *lines, buf = buf.split("\n")
            for raw in lines:
                line = ansi.sub("", raw).rstrip("\r")
                if "sign in with this QR code" in line:
                    in_qr, qr_lines = True, []
                    continue
                if in_qr:
                    # Blank margin lines around the code don't end it
                    if not line.strip():
                        continue
                    if "██" in line:
                        qr_lines.append(line)
                        continue
                    show_qr()
                m = re.match(r"\s*(\d+(?:\.\d+)?)%", line)
                if m:
                    out(state="progress", percent=float(m.group(1)))
                elif re.search(r"(?i)(error|failed|denied|not available|invalid)", line):
                    out(state="log", line=line.strip()[:300])
        if not asked_password:
            _, status = os.waitpid(pid, 0)
            reaped = True
    finally:
        if not reaped:  # cancelled: stop it too, drop the partial download
            try:
                os.kill(pid, signal.SIGTERM)
                os.waitpid(pid, 0)
            except OSError:
                pass
            shutil.rmtree(tmp, ignore_errors=True)
        if qr_path:
            try:
                os.remove(qr_path)
            except OSError:
                pass
        depot_stash()
    if asked_password:
        try:
            os.remove(marker)
        except OSError:
            pass
        out(state="error", error="Steam needs you to sign in again: download it once more to get a new code", signin=True)
        return
    shutil.rmtree(os.path.join(tmp, ".DepotDownloader"), ignore_errors=True)
    if os.WEXITSTATUS(status) != 0 or not os.path.isfile(os.path.join(tmp, "project.json")):
        shutil.rmtree(tmp, ignore_errors=True)
        out(state="error", error="The download failed (does this account own Wallpaper Engine?)")
        return
    shutil.rmtree(target, ignore_errors=True)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    os.replace(tmp, target)
    # Signed in with the QR code: remember who, so next time needs no code.
    # The account name is the keyring session's (the same Steam account).
    if not account:
        name = load().get("account", "")
        if name:
            with open(marker, "w") as f:
                f.write(name)
    out(state="done", path=target)


def secure_depot_store() -> None:
    """DepotDownloader keeps its remembered session in .NET isolated storage:
    readable by this user only."""
    root = os.path.expanduser("~/.local/share/IsolatedStorage")
    for d, dirs, files in os.walk(root):
        os.chmod(d, 0o700)
        for f in files:
            os.chmod(os.path.join(d, f), 0o600)


def remove(item: str) -> None:
    target = os.path.realpath(os.path.join(LIBRARY, "workshop", item))
    # Only ever a folder inside the library's workshop/
    if os.path.dirname(target) != os.path.realpath(os.path.join(LIBRARY, "workshop")) or not os.path.isdir(target):
        out(error="Not in the library")
        return
    shutil.rmtree(target)
    out(ok=True)


def main() -> int:
    # Cancelled (the settings app stops it): clean up like a normal exit
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "login":
        login()
    elif cmd == "status":
        s = load()
        exp = jwt(s.get("refresh", "")).get("exp", 0)
        out(signedIn=bool(s.get("refresh")) and exp > time.time(), account=s.get("account", ""), expires=exp)
    elif cmd == "logout":
        clear()
        out(ok=True)
    elif cmd == "download" and len(sys.argv) > 2 and sys.argv[2].isdigit():
        download(sys.argv[2])
    elif cmd == "remove" and len(sys.argv) > 2 and sys.argv[2].isdigit():
        remove(sys.argv[2])
    elif cmd in ("subscribe", "unsubscribe") and len(sys.argv) > 2 and sys.argv[2].isdigit():
        subscription(sys.argv[2], cmd == "subscribe")
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
