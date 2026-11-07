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
"""

import base64
import json
import os
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

def load() -> dict:
    try:
        r = subprocess.run(["secret-tool", "lookup", *KEYRING], capture_output=True, text=True, timeout=10)
        return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else {}
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return {}


def save(session: dict) -> bool:
    try:
        r = subprocess.run(["secret-tool", "store", "--label=Steam sign-in (Caelestia live wallpapers)", *KEYRING],
                           input=json.dumps(session), text=True, capture_output=True, timeout=10)
        return r.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def clear() -> None:
    subprocess.run(["secret-tool", "clear", *KEYRING], capture_output=True, timeout=10)


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
    elif cmd in ("subscribe", "unsubscribe") and len(sys.argv) > 2 and sys.argv[2].isdigit():
        subscription(sys.argv[2], cmd == "subscribe")
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
