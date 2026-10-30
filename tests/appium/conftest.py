"""
Appium conftest.py — Android emulator driver setup.
App: EduBoard Mobile (com.eduboard.mobile)
"""
import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))
import json
import time
import pytest
from datetime import datetime

BASE_URL = os.environ.get("APPIUM_SERVER", "http://localhost:4723")
APK_PATH = os.environ.get("APK_PATH", os.path.join(
    os.path.dirname(__file__), "apk", "eduboard_debug.apk"
))
RESULTS_FILE = os.path.join(os.path.dirname(__file__), "appium_results.json")

_results = []

CAPABILITIES = {
    "platformName": "Android",
    "appium:automationName": "UiAutomator2",
    "appium:deviceName": "Android Emulator",
    "appium:app": APK_PATH,
    "appium:appPackage": "com.eduboard.mobile",
    "appium:appActivity": "com.eduboard.mobile.MainActivity",
    "appium:noReset": False,
    "appium:fullReset": False,
    "appium:newCommandTimeout": 120,
    "appium:autoGrantPermissions": True,
    "appium:skipDeviceInitialization": False,
    "appium:uiautomator2ServerLaunchTimeout": 60000,
}


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
        "dashboard": "Dashboard", "drawspace": "DrawSpace",
        "doccanvas": "DocCanvas", "voice": "VoiceBoard",
        "profile": "Profile", "settings": "Settings",
        "nav": "Navigation", "history": "History",
        "notif": "Notifications", "onboard": "Onboarding",
        "help": "Help", "security": "Security",
        "ui": "UI/UX", "perf": "Performance",
    }
    lower = nodeid.lower()
    for key, cat in mapping.items():
        if key in lower:
            return cat
    return "Functional"


def pytest_sessionfinish(session, exitstatus):
    with open(RESULTS_FILE, "w") as f:
        json.dump(_results, f, indent=2)


@pytest.fixture(scope="function")
def driver():
    """Create Appium driver connected to Android emulator."""
    try:
        from appium import webdriver as appium_webdriver
        from appium.options import UiAutomator2Options
        options = UiAutomator2Options()
        for key, value in CAPABILITIES.items():
            clean_key = key.replace("appium:", "")
            try:
                setattr(options, clean_key, value)
            except Exception:
                pass
        options.app = APK_PATH
        dr = appium_webdriver.Remote(BASE_URL, options=options)
        dr.implicitly_wait(10)
        yield dr
        dr.quit()
    except Exception as e:
        yield None


@pytest.fixture(scope="session")
def appium_server():
    return BASE_URL

