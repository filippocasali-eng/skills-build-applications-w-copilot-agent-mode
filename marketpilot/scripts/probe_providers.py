#!/usr/bin/env python3
"""Live probe of MarketPilot AI data sources (run on CI with real network access).

Prints real response samples and validates catalog symbols / SEC identifiers. Exit code is always 0:
this is a diagnostic report, the pass/fail verdicts come from the Gradle live tests.
"""
import json
import urllib.request

UA = {"User-Agent": "MarketPilotAI/1.0 (personal research app; contact marketpilot-ci@example.com)"}


def get(url, limit=None):
    req = urllib.request.Request(url, headers=UA)
    data = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
    return data if limit is None else data[:limit]


def section(title):
    print("\n==================== " + title)


def safe(fn):
    try:
        fn()
    except Exception as e:  # noqa: BLE001 - diagnostic script
        print("ERROR:", type(e).__name__, e)


def yahoo_symbols():
    section("Yahoo chart: catalog symbols")
    symbols = ["SPY", "QQQ", "^GSPC", "^NDX", "VWCE.DE", "VGWL.DE", "EUNL.DE", "SXR8.DE", "VUAA.DE", "CSPX.L", "SXRV.DE",
               "XLK", "XLRE", "XLC", "BRK-B", "AAPL"]
    for s in symbols:
        try:
            j = json.loads(get(f"https://query1.finance.yahoo.com/v8/finance/chart/{s}?range=5d&interval=1d&includeAdjustedClose=true"))
            r = j["chart"]["result"][0]
            m = r["meta"]
            closes = r["indicators"]["quote"][0]["close"]
            print(f"{s:10} OK {m.get('currency')} {m.get('fullExchangeName')} tz={m.get('exchangeTimezoneName')} bars={len(r.get('timestamp', []))} last={closes[-1]} adj={'adjclose' in r['indicators']}")
        except Exception as e:  # noqa: BLE001
            print(f"{s:10} FAIL {e}")


def yahoo_sample():
    section("Yahoo chart sample AAPL 1mo")
    print(get("https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1mo&interval=1d&includeAdjustedClose=true", 5000))


def form4():
    section("SEC Form 4 sample (AAPL)")
    sub = json.loads(get("https://data.sec.gov/submissions/CIK0000320193.json"))
    r = sub["filings"]["recent"]
    for i, f in enumerate(r["form"]):
        if f == "4":
            acc, doc = r["accessionNumber"][i], r["primaryDocument"][i]
            print("accession", acc, "primaryDocument", doc, "filingDate", r["filingDate"][i])
            raw = doc.split("/")[-1]
            print(get(f"https://www.sec.gov/Archives/edgar/data/320193/{acc.replace('-', '')}/{raw}", 7000))
            break
    print("recent keys:", list(r.keys()))


def thirteen_f():
    section("SEC 13F-HR sample (Berkshire Hathaway CIK 1067983)")
    sub = json.loads(get("https://data.sec.gov/submissions/CIK0001067983.json"))
    print("name:", sub["name"])
    r = sub["filings"]["recent"]
    for i, f in enumerate(r["form"]):
        if f == "13F-HR":
            acc = r["accessionNumber"][i]
            print("accession", acc, "reportDate", r["reportDate"][i], "filingDate", r["filingDate"][i], "primary", r["primaryDocument"][i])
            idx = json.loads(get(f"https://www.sec.gov/Archives/edgar/data/1067983/{acc.replace('-', '')}/index.json"))
            names = [it["name"] for it in idx["directory"]["item"]]
            print("files:", names)
            for n in names:
                if n.lower().endswith(".xml") and n != "primary_doc.xml":
                    print(get(f"https://www.sec.gov/Archives/edgar/data/1067983/{acc.replace('-', '')}/{n}", 3500))
                    break
            break


def managers():
    section("13F manager CIKs")
    for cik in ["1067983", "1336528", "1649339", "1656456", "1040273", "1079114", "1061768", "1536411"]:
        try:
            sub = json.loads(get(f"https://data.sec.gov/submissions/CIK{cik.zfill(10)}.json"))
            forms = sub["filings"]["recent"]["form"]
            print(cik, sub["name"], "13F-HR count in recent:", forms.count("13F-HR"))
        except Exception as e:  # noqa: BLE001
            print(cik, "FAIL", e)


def companyfacts():
    section("SEC XBRL companyfacts structure (AAPL)")
    j = json.loads(get("https://data.sec.gov/api/xbrl/companyfacts/CIK0000320193.json"))
    gaap = j["facts"]["us-gaap"]
    for tag in ["Revenues", "RevenueFromContractWithCustomerExcludingAssessedTax", "NetIncomeLoss", "OperatingIncomeLoss",
                "NetCashProvidedByUsedInOperatingActivities", "PaymentsToAcquirePropertyPlantAndEquipment", "LongTermDebt",
                "LongTermDebtNoncurrent", "StockholdersEquity", "EarningsPerShareDiluted"]:
        if tag in gaap:
            units = gaap[tag]["units"]
            unit = list(units.keys())[0]
            items = units[unit]
            annual = [x for x in items if x.get("form") == "10-K" and x.get("fp") == "FY"]
            print(tag, unit, "n=", len(items), "last FY:", json.dumps(annual[-1]) if annual else None)
        else:
            print(tag, "MISSING")
    dei = j["facts"].get("dei", {})
    so = dei.get("EntityCommonStockSharesOutstanding", {}).get("units", {}).get("shares", [])
    print("shares outstanding last:", json.dumps(so[-1]) if so else None)


def alpha_vantage_demo():
    section("Alpha Vantage public demo key (IBM)")
    print(get("https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=IBM&apikey=demo", 900))
    print(get("https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=IBM&apikey=demo", 600))


def reddit_token_endpoint():
    section("Reddit OAuth endpoint reachability (no credentials)")
    try:
        req = urllib.request.Request("https://www.reddit.com/api/v1/access_token", data=b"grant_type=https%3A%2F%2Foauth.reddit.com%2Fgrants%2Finstalled_client&device_id=DO_NOT_TRACK_THIS_DEVICE", headers=UA)
        urllib.request.urlopen(req, timeout=20)
    except Exception as e:  # noqa: BLE001
        print("expected auth failure without client id:", e)


for fn in [yahoo_symbols, yahoo_sample, form4, thirteen_f, managers, companyfacts, alpha_vantage_demo, reddit_token_endpoint]:
    safe(fn)
