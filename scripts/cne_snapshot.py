#!/usr/bin/env python3
"""Download the CNE fuel price feeds (places + prices) and write a daily summary.

Usage:
    python3 scripts/cne_snapshot.py --out data/cne-monitor

Writes, inside --out:
    YYYY-MM-DD/summary.json      summary of this run (UTC date)
    summaries.jsonl              one line per run (appended)
    latest/places.xml.gz         raw copy of the last download
    latest/prices.xml.gz         raw copy of the last download (used to diff the next day)

Only the Python standard library is used, so it runs on any GitHub runner.
Exit code is 0 when both files were downloaded and parsed, 1 otherwise
(the summary is still written so failures are recorded).
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import gzip
import hashlib
import json
import re
import statistics
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

BASE_URL = "https://publicacionexterna.azurewebsites.net/publicaciones"
FEEDS = ("places", "prices")
PERMIT_RE = re.compile(r"PL/\d+/EXP/ES/\d{4}")
# Rough bounding box of Mexico (lon, lat).
MX_BBOX = (-118.5, 14.4, -86.5, 32.8)
PRICE_MIN, PRICE_MAX = 15.0, 40.0  # MXN/l; outside this range counts as suspicious


def download(name: str, retries: int = 4) -> tuple[bytes | None, dict]:
    url = f"{BASE_URL}/{name}"
    meta: dict = {"url": url}
    for attempt in range(retries):
        started = time.monotonic()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "gasol-cne-monitor/1.0"})
            with urllib.request.urlopen(req, timeout=180) as resp:
                body = resp.read()
                meta.update(
                    status=resp.status,
                    bytes=len(body),
                    sha256=hashlib.sha256(body).hexdigest(),
                    seconds=round(time.monotonic() - started, 2),
                    attempts=attempt + 1,
                    last_modified=resp.headers.get("Last-Modified"),
                    etag=resp.headers.get("ETag"),
                    server_date=resp.headers.get("Date"),
                )
                return body, meta
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            meta.update(error=f"{type(exc).__name__}: {exc}", attempts=attempt + 1)
            time.sleep(2 ** (attempt + 1))
    return None, meta


def summarize_places(root: ET.Element) -> tuple[dict, set[str]]:
    ids: set[str] = set()
    issues = collections.Counter()
    decimals = collections.Counter()
    coords = collections.Counter()
    permits = collections.Counter()
    for p in root.findall("place"):
        pid = p.get("place_id") or ""
        if pid in ids:
            issues["duplicate_place_id"] += 1
        ids.add(pid)
        permit = (p.findtext("cre_id") or "").strip()
        permits[permit] += 1
        if not PERMIT_RE.fullmatch(permit):
            issues["permit_nonstandard_format"] += 1
        if not (p.findtext("name") or "").strip():
            issues["name_missing"] += 1
        xs, ys = (p.findtext("location/x") or "").strip(), (p.findtext("location/y") or "").strip()
        try:
            x, y = float(xs), float(ys)
        except ValueError:
            issues["coords_missing"] += 1
            continue
        if x == 0 or y == 0:
            issues["coords_zero"] += 1
            continue
        if not (MX_BBOX[0] <= x <= MX_BBOX[2] and MX_BBOX[1] <= y <= MX_BBOX[3]):
            issues["coords_outside_mexico"] += 1
        d = min(len(xs.partition(".")[2]), len(ys.partition(".")[2]))
        decimals[str(d)] += 1
        coords[(x, y)] += 1
    issues["duplicate_permit"] = sum(1 for v in permits.values() if v > 1)
    issues["places_sharing_coords"] = sum(v for v in coords.values() if v > 1)
    return {
        "places": len(ids),
        "issues": dict(issues),
        "coord_decimals": dict(sorted(decimals.items())),
    }, ids


def summarize_prices(root: ET.Element, place_ids: set[str] | None) -> tuple[dict, dict]:
    # A place can appear in several <place> blocks; merge them.
    merged: dict[str, dict[str, list[float]]] = collections.defaultdict(lambda: collections.defaultdict(list))
    blocks = 0
    bad_values = 0
    for p in root.findall("place"):
        blocks += 1
        pid = p.get("place_id") or ""
        for g in p.findall("gas_price"):
            try:
                merged[pid][g.get("type") or "?"].append(float(g.text or ""))
            except ValueError:
                bad_values += 1
    by_fuel: dict[str, list[float]] = collections.defaultdict(list)
    conflicts = 0
    flat: dict[str, dict[str, float]] = {}
    for pid, fuels in merged.items():
        flat[pid] = {}
        for fuel, vals in fuels.items():
            if len(set(vals)) > 1:
                conflicts += 1
            flat[pid][fuel] = vals[-1]
            by_fuel[fuel].append(vals[-1])
    fuels_summary = {}
    for fuel, vals in sorted(by_fuel.items()):
        vals.sort()
        n = len(vals)
        fuels_summary[fuel] = {
            "stations": n,
            "min": vals[0],
            "p01": vals[n // 100],
            "median": statistics.median(vals),
            "p99": vals[min(n - 1, n * 99 // 100)],
            "max": vals[-1],
            "suspicious": sum(1 for v in vals if v < PRICE_MIN or v > PRICE_MAX),
        }
    out = {
        "place_blocks": blocks,
        "stations_with_price": len(merged),
        "stations_in_several_blocks": blocks - len(merged),
        "same_fuel_conflicting_prices": conflicts,
        "unparseable_prices": bad_values,
        "fuels": fuels_summary,
    }
    if place_ids is not None:
        out["prices_without_place"] = len(set(merged) - place_ids)
        out["places_without_prices"] = len(place_ids - set(merged))
    return out, flat


def diff_prices(prev: dict[str, dict[str, float]], cur: dict[str, dict[str, float]]) -> dict:
    changed_stations = 0
    changed_prices = 0
    for pid, fuels in cur.items():
        old = prev.get(pid)
        if old is None:
            continue
        c = sum(1 for f, v in fuels.items() if f in old and old[f] != v)
        changed_prices += c
        changed_stations += 1 if c else 0
    return {
        "stations_new": len(set(cur) - set(prev)),
        "stations_gone": len(set(prev) - set(cur)),
        "stations_with_price_change": changed_stations,
        "price_changes": changed_prices,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="data/cne-monitor", type=Path)
    args = ap.parse_args()

    now = dt.datetime.now(dt.timezone.utc)
    summary: dict = {"run_at_utc": now.isoformat(timespec="seconds"), "ok": True, "downloads": {}}
    latest = args.out / "latest"
    prev_prices = None
    prev_path = latest / "prices.xml.gz"
    if prev_path.exists():
        try:
            _, prev_prices = summarize_prices(ET.fromstring(gzip.decompress(prev_path.read_bytes())), None)
        except (OSError, ET.ParseError):
            prev_prices = None

    bodies: dict[str, bytes] = {}
    for name in FEEDS:
        body, meta = download(name)
        summary["downloads"][name] = meta
        if body is None or meta.get("status") != 200:
            summary["ok"] = False
        else:
            bodies[name] = body

    place_ids = None
    roots: dict[str, ET.Element] = {}
    for name, body in bodies.items():
        try:
            roots[name] = ET.fromstring(body)
        except ET.ParseError as exc:
            summary["ok"] = False
            summary["downloads"][name]["parse_error"] = str(exc)
    if "places" in roots:
        summary["places"], place_ids = summarize_places(roots["places"])
    if "prices" in roots:
        summary["prices"], cur_prices = summarize_prices(roots["prices"], place_ids)
        if prev_prices is not None:
            summary["vs_previous_run"] = diff_prices(prev_prices, cur_prices)

    day_dir = args.out / now.strftime("%Y-%m-%d")
    day_dir.mkdir(parents=True, exist_ok=True)
    latest.mkdir(parents=True, exist_ok=True)
    for name, body in bodies.items():
        if name in roots:
            (latest / f"{name}.xml.gz").write_bytes(gzip.compress(body, 9, mtime=0))
    text = json.dumps(summary, ensure_ascii=False, indent=2)
    (day_dir / "summary.json").write_text(text + "\n", encoding="utf-8")
    with (args.out / "summaries.jsonl").open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(summary, ensure_ascii=False) + "\n")
    print(text)
    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
