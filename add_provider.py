#!/usr/bin/env python3
"""Tambah / lihat / hapus provider LLM di config.yaml Hermes tanpa redeploy.

Dibuat supaya agent cukup menjalankan SATU perintah terminal pendek, tanpa
menulis kode panjang atau JSON bersarang lewat execute_code (itu yang sering
rusak di model reasoning).

Contoh:
  python add_provider.py rel1 https://host/v1 --key sk-xxx --model nama-model
  python add_provider.py rel2 https://host/v1 --key-env REL2_API_KEY
  python add_provider.py rel3 https://host/anthropic --key sk-yyy --transport anthropic_messages
  python add_provider.py --list
  python add_provider.py --remove rel2

Setelah itu pindah provider di Telegram:  /model custom:<nama>:<model>

Catatan skema (dari dokumentasi Hermes, blok `providers:`):
  api, key_env, transport, default_model.
Format lama `custom_providers:` (list) tidak disentuh.
"""
import argparse
import glob
import os
import re
import shutil
import sys
import tempfile
import time

try:
    import yaml
except ImportError:
    sys.exit(
        "PyYAML tidak ketemu. Jalankan dengan Python milik Hermes:\n"
        "  /opt/hermes/.venv/bin/python /opt/add_provider.py ..."
    )

HOME = os.environ.get("HERMES_HOME", "/opt/data")
CONFIG = os.path.join(HOME, "config.yaml")
ENVFILE = os.path.join(HOME, ".env")

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,39}$")
ENV_RE = re.compile(r"^[A-Z_][A-Z0-9_]*$")
KEY_RE = re.compile(r"^[A-Za-z0-9._~+/=:-]{8,}$")
TRANSPORTS = ("chat_completions", "anthropic_messages", "codex_responses")


def die(msg):
    print("ERROR: " + msg, file=sys.stderr)
    sys.exit(1)


def mask(secret):
    return secret[:4] + "..." + secret[-2:] if len(secret) > 10 else "***"


def load_config():
    if not os.path.exists(CONFIG):
        return {}
    with open(CONFIG, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if data is None:
        return {}
    if not isinstance(data, dict):
        die(CONFIG + " bukan YAML dict, tidak diubah.")
    return data


def atomic_write(path, text, mode=None):
    d = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        if mode is not None:
            os.chmod(tmp, mode)
        elif os.path.exists(path):
            shutil.copymode(path, tmp)
        os.replace(tmp, path)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def backup_config():
    if not os.path.exists(CONFIG):
        return None
    dst = CONFIG + ".bak-" + time.strftime("%Y%m%d-%H%M%S")
    shutil.copy2(CONFIG, dst)
    for old in sorted(glob.glob(CONFIG + ".bak-*"))[:-5]:
        os.unlink(old)
    return dst


def save_config(cfg):
    os.makedirs(HOME, exist_ok=True)
    backup_config()
    text = yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True, default_flow_style=False)
    atomic_write(CONFIG, text)


def set_env_key(var, value):
    lines = []
    if os.path.exists(ENVFILE):
        with open(ENVFILE, "r", encoding="utf-8") as f:
            lines = f.read().splitlines()
    new_line = "%s=%s" % (var, value)
    for i, line in enumerate(lines):
        if line.split("=", 1)[0].strip() == var:
            lines[i] = new_line
            break
    else:
        lines.append(new_line)
    atomic_write(ENVFILE, "\n".join(lines) + "\n", mode=0o600)


def env_has(var):
    if var in os.environ:
        return True
    if os.path.exists(ENVFILE):
        with open(ENVFILE, "r", encoding="utf-8") as f:
            return any(l.split("=", 1)[0].strip() == var for l in f.read().splitlines())
    return False


def get_providers(cfg):
    prov = cfg.get("providers")
    if prov is None:
        prov = {}
    if not isinstance(prov, dict):
        die("`providers` di config.yaml bukan dict, tidak diubah.")
    return prov


def cmd_list():
    cfg = load_config()
    prov = get_providers(cfg)
    if not prov:
        print("(belum ada provider di blok `providers:`)")
    for name, e in prov.items():
        e = e if isinstance(e, dict) else {}
        key = e.get("key_env") or ("api_key (di config)" if e.get("api_key") else "-")
        print("- %s | api=%s | transport=%s | model=%s | key=%s" % (
            name,
            e.get("api") or e.get("base_url") or e.get("url") or "?",
            e.get("transport", "-"),
            e.get("default_model", "-"),
            key,
        ))
    legacy = cfg.get("custom_providers")
    if isinstance(legacy, list) and legacy:
        names = [str(x.get("name", "?")) for x in legacy if isinstance(x, dict)]
        print("Format lama custom_providers (tidak diubah): " + ", ".join(names))


def cmd_remove(name):
    cfg = load_config()
    prov = get_providers(cfg)
    if name not in prov:
        die("provider '%s' tidak ada." % name)
    del prov[name]
    cfg["providers"] = prov
    save_config(cfg)
    print("Dihapus: %s. (Baris key di %s kalau ada tidak dihapus.)" % (name, ENVFILE))


def cmd_add(a):
    if not a.name or not a.base_url:
        die("pakai: add_provider.py NAMA BASE_URL [--key KEY | --key-env VAR] [--model M] [--transport T]")
    if not NAME_RE.match(a.name):
        die("NAMA hanya boleh huruf kecil, angka, - dan _ (maks 40), tanpa spasi atau titik dua.")
    if not re.match(r"^https?://[^\s]+$", a.base_url):
        die("BASE_URL harus diawali http:// atau https:// tanpa spasi.")

    entry = {"api": a.base_url.rstrip("/"), "transport": a.transport}

    if a.key:
        if not KEY_RE.match(a.key):
            die("KEY mengandung karakter yang tidak didukung atau terlalu pendek.")
        var = a.name.upper().replace("-", "_") + "_API_KEY"
        set_env_key(var, a.key)
        entry["key_env"] = var
        key_info = "key disimpan di %s sebagai %s (%s)" % (ENVFILE, var, mask(a.key))
    elif a.key_env:
        if not ENV_RE.match(a.key_env):
            die("--key-env harus nama variable seperti MY_API_KEY.")
        entry["key_env"] = a.key_env
        key_info = "key dibaca dari variable %s" % a.key_env
        if not env_has(a.key_env):
            key_info += " (PERINGATAN: variable itu belum ada di lingkungan maupun %s)" % ENVFILE
    else:
        key_info = "tanpa key"

    if a.model:
        entry["default_model"] = a.model

    cfg = load_config()
    prov = get_providers(cfg)
    existed = a.name in prov
    prov[a.name] = entry
    cfg["providers"] = prov
    save_config(cfg)

    print("%s provider '%s'" % ("Diperbarui" if existed else "Ditambah", a.name))
    print("  api=%s transport=%s model=%s" % (entry["api"], entry["transport"], entry.get("default_model", "-")))
    print("  " + key_info)
    print("Pindah di Telegram: /model custom:%s:%s" % (a.name, a.model or "<nama-model>"))
    print("Kalau provider belum muncul, restart gateway (config dibaca saat start).")


def main():
    p = argparse.ArgumentParser(description="Kelola provider LLM Hermes di config.yaml")
    p.add_argument("name", nargs="?", help="nama provider (huruf kecil, angka, - _)")
    p.add_argument("base_url", nargs="?", help="base URL, contoh https://host/v1")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--key", help="API key; disimpan di .env, bukan di config.yaml")
    g.add_argument("--key-env", help="nama variable env yang berisi API key")
    p.add_argument("--model", help="model default provider ini")
    p.add_argument("--transport", default="chat_completions", choices=TRANSPORTS)
    p.add_argument("--list", action="store_true", help="tampilkan semua provider (tanpa key)")
    p.add_argument("--remove", metavar="NAMA", help="hapus provider")
    a = p.parse_args()

    if a.list:
        cmd_list()
    elif a.remove:
        cmd_remove(a.remove)
    else:
        cmd_add(a)


if __name__ == "__main__":
    main()
