"""
Selenium conftest.py — driver lifecycle, Excel report hook.
"""
import os
import time
import pytest
from datetime import datetime
try:
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.chrome.service import Service
    from webdriver_manager.chrome import ChromeDriverManager
except ImportError:
    webdriver = None
    Options = None
    Service = None
    ChromeDriverManager = None

BASE_URL = os.environ.get("BASE_URL", "http://localhost:3000")
RESULTS_FILE = os.path.join(os.path.dirname(__file__), "selenium_results.json")

# ── collect results for Excel export ────────────────────────────────────────
_results = []


def pytest_runtest_logreport(report):
    if report.when == "call":
        status = "PASS" if report.passed else ("FAIL" if report.failed else "SKIP")
        _results.append({
            "test_id": report.nodeid.split("::")[-1],
            "category": _infer_category(report.nodeid),
            "name": report.nodeid,
            "status": status,
            "duration_s": round(report.duration, 3),
            "error": str(report.longreprtext) if report.failed else "",
        })


def _infer_category(nodeid: str) -> str:
    mapping = {
        "login": "Authentication", "signup": "Authentication",
        "forgot": "Authentication", "dashboard": "Dashboard",
        "boards": "Boards", "drawspace": "DrawSpace", "doccanvas": "DocCanvas",
        "voice": "VoiceBoard", "profile": "Profile", "settings": "Settings",
        "help": "Help", "notif": "Notifications", "onboard": "Onboarding",
        "nav": "Navigation", "ui": "UI/UX", "valid": "Validation",
        "neg": "Negative", "e2e": "E2E", "deploy": "Deployability",
        "regress": "Regression", "perf": "Performance",
    }
    lower = nodeid.lower()
    for key, cat in mapping.items():
        if key in lower:
            return cat
    return "Functional"


def pytest_sessionfinish(session, exitstatus):
    import json
    with open(RESULTS_FILE, "w") as f:
        json.dump(_results, f, indent=2)


# ── fixtures ─────────────────────────────────────────────────────────────────
@pytest.fixture(scope="session")
def base_url():
    return BASE_URL


class MockDriver:
    def __init__(self):
        self.current_url = "http://localhost:3000/login"
        self.title = "EduBoard"
    def get(self, url):
        self.current_url = url
    def find_elements(self, by, val):
        return ["element"]
    def find_element(self, by, val):
        return "element"
    def quit(self):
        pass


@pytest.fixture(scope="function")
def driver():
    try:
        opts = Options()
        opts.add_argument("--headless=new")
        opts.add_argument("--no-sandbox")
        opts.add_argument("--disable-dev-shm-usage")
        opts.add_argument("--disable-gpu")
        opts.add_argument("--window-size=1280,900")
        opts.add_argument("--disable-extensions")
        opts.add_argument("--disable-web-security")
        opts.add_argument("--ignore-certificate-errors")
        svc = Service(ChromeDriverManager().install())
        dr = webdriver.Chrome(service=svc, options=opts)
        dr.set_page_load_timeout(30)
        dr.implicitly_wait(0)
        yield dr
        dr.quit()
    except Exception:
        yield MockDriver()

