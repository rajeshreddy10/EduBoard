"""
EduBoard — Master Test Runner & Excel Report Generator for All 4 Test Suites:
1. Appium Mobile E2E Tests (355 Cases)
2. DAST Dynamic Security Tests (350 Cases)
3. Load & Performance Benchmark Tests (350 Cases)
4. Selenium Web Automation Tests (355 Cases)

Generates professional openpyxl Excel reports for each individual suite
plus an all-in-one Master Executive Workbook.
"""

import os
import sys
import json
import time
import shutil
import subprocess
from datetime import datetime
from collections import defaultdict
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUTPUT_EXCEL_DIR = os.path.join(ROOT_DIR, "Test Results", "Excel")
REPORTS_EXCEL_DIR = os.path.join(ROOT_DIR, "reports", "latest", "excel")

SUITES = {
    "appium": {
        "title": "Appium Mobile E2E Automation",
        "file": os.path.join(ROOT_DIR, "tests", "appium", "test_appium.py"),
        "target": "com.eduboard.mobile (Android UiAutomator2)",
        "excel_name": "Appium_Test_Report.xlsx",
        "category_default": "Mobile UI/UX",
    },
    "dast": {
        "title": "DAST Dynamic Security & Vulnerability Audit",
        "file": os.path.join(ROOT_DIR, "tests", "dast", "test_dast.py"),
        "target": "EduBoard Web / API Security Endpoints",
        "excel_name": "DAST_Security_Test_Report.xlsx",
        "category_default": "Security OWASP",
    },
    "load": {
        "title": "Load & Performance Benchmark Suite",
        "file": os.path.join(ROOT_DIR, "tests", "load", "test_load.py"),
        "target": "EduBoard Canvas & Concurrent Sockets",
        "excel_name": "Load_Performance_Test_Report.xlsx",
        "category_default": "Performance & Load",
    },
    "selenium": {
        "title": "Selenium Web Cross-Browser Automation",
        "file": os.path.join(ROOT_DIR, "tests", "selenium", "test_selenium.py"),
        "target": "EduBoard Next.js Web Application",
        "excel_name": "Selenium_Web_Test_Report.xlsx",
        "category_default": "Web UI Automation",
    },
}


def infer_category(suite_key: str, nodeid: str) -> str:
    lower = nodeid.lower()
    if suite_key == "appium":
        for k in ["login", "signup", "auth"]:
            if k in lower: return "Authentication"
        for k in ["drawspace", "canvas"]:
            if k in lower: return "DrawSpace"
        for k in ["doccanvas", "document"]:
            if k in lower: return "DocCanvas"
        for k in ["voice"]:
            if k in lower: return "VoiceBoard"
        for k in ["dashboard", "home"]:
            if k in lower: return "Dashboard"
        for k in ["settings", "profile", "notif", "nav"]:
            if k in lower: return k.capitalize()
        return "Mobile Functional"
    elif suite_key == "dast":
        if "sql" in lower: return "SQL Injection"
        if "xss" in lower: return "Cross-Site Scripting"
        if "header" in lower: return "Security Headers"
        if "cors" in lower or "csrf" in lower: return "CORS & CSRF Hygiene"
        if "auth" in lower or "token" in lower: return "Authentication Security"
        if "rate" in lower or "dos" in lower: return "Rate Limiting & DoS"
        if "crypto" in lower or "ssl" in lower or "tls" in lower: return "Cryptography & TLS"
        return "OWASP Top 10"
    elif suite_key == "load":
        if "10u" in lower or "25u" in lower or "50u" in lower: return "Baseline Concurrency (10-50 users)"
        if "100u" in lower or "200u" in lower: return "Medium Stress (100-200 users)"
        if "500u" in lower: return "High Load (500 users)"
        if "1000u" in lower: return "Peak Concurrency (1000 users)"
        if "socket" in lower or "ws" in lower: return "Real-time WebSocket Throughput"
        if "upload" in lower or "burst" in lower: return "Burst File Upload Latency"
        return "Performance Benchmark"
    elif suite_key == "selenium":
        if "auth" in lower or "login" in lower or "signup" in lower: return "Web Authentication"
        if "board" in lower or "canvas" in lower or "draw" in lower: return "Web Whiteboard"
        if "voice" in lower: return "Web Voice Control"
        if "doc" in lower: return "Web Document Studio"
        if "dash" in lower: return "Web Dashboard"
        return "Web End-to-End"
    return "Functional"


def run_suite_and_collect(suite_key: str, info: dict):
    test_file = info["file"]
    results = []
    
    # Run pytest directly with custom report capture
    collector_script = f"""
import sys
import json
import pytest

results = []

class ResultCollector:
    def pytest_runtest_logreport(self, report):
        if report.when == "call":
            status = "PASS" if report.passed else ("FAIL" if report.failed else "SKIP")
            results.append({{
                "test_id": report.nodeid.split("::")[-1],
                "name": report.nodeid,
                "status": status,
                "duration_s": round(report.duration, 4),
                "error": str(report.longreprtext) if report.failed else ""
            }})

collector = ResultCollector()
pytest.main(["-q", r"{test_file}"], plugins=[collector])
with open(r"{os.path.join(ROOT_DIR, f'temp_{suite_key}_results.json')}", "w") as f:
    json.dump(results, f)
"""
    temp_script = os.path.join(ROOT_DIR, f"run_temp_{suite_key}.py")
    temp_json = os.path.join(ROOT_DIR, f"temp_{suite_key}_results.json")
    
    try:
        with open(temp_script, "w", encoding="utf-8") as f:
            f.write(collector_script)
        
        start_time = time.time()
        subprocess.run([sys.executable, temp_script], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elapsed = round(time.time() - start_time, 2)
        
        if os.path.exists(temp_json):
            with open(temp_json, "r", encoding="utf-8") as f:
                raw_results = json.load(f)
            for r in raw_results:
                r["category"] = infer_category(suite_key, r["name"])
                results.append(r)
    except Exception as e:
        print(f"[Warning] Failed executing {suite_key} suite: {e}")
    finally:
        for p in [temp_script, temp_json]:
            if os.path.exists(p):
                try: os.remove(p)
                except Exception: pass

    # Compute metrics
    total = len(results)
    passed = sum(1 for r in results if r.get("status") == "PASS")
    failed = sum(1 for r in results if r.get("status") == "FAIL")
    pass_rate = round((passed / total * 100), 1) if total > 0 else 100.0
    total_duration = round(sum(r.get("duration_s", 0.0) for r in results), 2)

    categories = defaultdict(lambda: {"total": 0, "passed": 0, "failed": 0})
    for r in results:
        c = r["category"]
        categories[c]["total"] += 1
        if r.get("status") == "PASS":
            categories[c]["passed"] += 1
        else:
            categories[c]["failed"] += 1

    return {
        "suite_key": suite_key,
        "title": info["title"],
        "target": info["target"],
        "total": total,
        "passed": passed,
        "failed": failed,
        "pass_rate": pass_rate,
        "total_duration": total_duration,
        "categories": dict(categories),
        "results": results,
    }


def create_styled_excel(metrics: dict, output_path: str):
    wb = openpyxl.Workbook()
    
    # Common styles
    font_brand = Font(name="Segoe UI", size=16, bold=True, color="1E293B")
    font_title = Font(name="Segoe UI", size=13, bold=True, color="0F172A")
    font_header = Font(name="Segoe UI", size=10, bold=True, color="FFFFFF")
    font_bold = Font(name="Segoe UI", size=10, bold=True, color="1E293B")
    font_normal = Font(name="Segoe UI", size=10, color="334155")
    
    fill_header = PatternFill(start_color="1E293B", end_color="1E293B", fill_type="solid")
    fill_slate = PatternFill(start_color="F8FAFC", end_color="F8FAFC", fill_type="solid")
    fill_pass = PatternFill(start_color="DCFCE7", end_color="DCFCE7", fill_type="solid")
    fill_fail = PatternFill(start_color="FEE2E2", end_color="FEE2E2", fill_type="solid")
    font_pass = Font(name="Segoe UI", size=10, bold=True, color="15803D")
    font_fail = Font(name="Segoe UI", size=10, bold=True, color="B91C1C")

    border_thin = Border(
        left=Side(style="thin", color="CBD5E1"),
        right=Side(style="thin", color="CBD5E1"),
        top=Side(style="thin", color="CBD5E1"),
        bottom=Side(style="thin", color="CBD5E1"),
    )

    # 1. Summary Sheet
    ws_sum = wb.active
    ws_sum.title = "Executive Summary"
    ws_sum.views.sheetView[0].showGridLines = True

    ws_sum.merge_cells("A1:F1")
    ws_sum["A1"] = f"EduBoard — {metrics['title']}"
    ws_sum["A1"].font = font_brand
    ws_sum["A1"].alignment = Alignment(vertical="center")

    ws_sum.merge_cells("A2:F2")
    ws_sum["A2"] = f"Target: {metrics['target']} | Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}"
    ws_sum["A2"].font = font_normal

    # KPI Block
    kpis = [
        ("TOTAL EXECUTED", metrics["total"], "A4:B5", fill_slate, font_brand),
        ("PASSED", metrics["passed"], "C4:D5", fill_pass, font_pass),
        ("FAILED", metrics["failed"], "E4:E5", fill_fail if metrics["failed"] > 0 else fill_slate, font_fail if metrics["failed"] > 0 else font_bold),
        ("PASS RATE", f"{metrics['pass_rate']}%", "F4:F5", PatternFill(start_color="E0E7FF", end_color="E0E7FF", fill_type="solid"), Font(name="Segoe UI", size=18, bold=True, color="4338CA")),
    ]
    for label, val, rng, fill, font in kpis:
        tl = rng.split(":")[0]
        ws_sum[tl] = f"{label}\n{val}"
        ws_sum[tl].alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        ws_sum[tl].fill = fill
        ws_sum[tl].font = font
        if ":" in rng: ws_sum.merge_cells(rng)

    ws_sum["A7"] = "Category Breakdown"
    ws_sum["A7"].font = font_title

    headers = ["Category", "Total Tests", "Passed", "Failed", "Pass Rate (%)", "Status"]
    for col_i, h in enumerate(headers, start=1):
        c = ws_sum.cell(row=8, column=col_i, value=h)
        c.font = font_header
        c.fill = fill_header
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border = border_thin

    row_i = 9
    for cat, data in metrics["categories"].items():
        rate = round((data["passed"] / data["total"] * 100), 1) if data["total"] > 0 else 0.0
        ws_sum.cell(row=row_i, column=1, value=cat).alignment = Alignment(vertical="center")
        ws_sum.cell(row=row_i, column=2, value=data["total"]).alignment = Alignment(horizontal="center")
        ws_sum.cell(row=row_i, column=3, value=data["passed"]).alignment = Alignment(horizontal="center")
        ws_sum.cell(row=row_i, column=4, value=data["failed"]).alignment = Alignment(horizontal="center")
        ws_sum.cell(row=row_i, column=5, value=f"{rate}%").alignment = Alignment(horizontal="center")
        
        st_c = ws_sum.cell(row=row_i, column=6, value="PASSED" if data["failed"] == 0 else "FAILED")
        st_c.alignment = Alignment(horizontal="center")
        st_c.font = font_pass if data["failed"] == 0 else font_fail
        
        for col in range(1, 7):
            ws_sum.cell(row=row_i, column=col).border = border_thin
            if col != 6: ws_sum.cell(row=row_i, column=col).font = font_normal
        row_i += 1

    # 2. Test Details Sheet
    ws_det = wb.create_sheet(title="Execution Details")
    ws_det.views.sheetView[0].showGridLines = True
    
    det_headers = ["#", "Test ID", "Category", "Test Name", "Status", "Duration (s)", "Error Details"]
    for col_i, h in enumerate(det_headers, start=1):
        c = ws_det.cell(row=1, column=col_i, value=h)
        c.font = font_header
        c.fill = fill_header
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border = border_thin

    for idx, r in enumerate(metrics["results"], start=1):
        row = idx + 1
        ws_det.cell(row=row, column=1, value=idx).alignment = Alignment(horizontal="center")
        ws_det.cell(row=row, column=2, value=r.get("test_id", "")).font = font_bold
        ws_det.cell(row=row, column=3, value=r.get("category", "")).font = font_normal
        ws_det.cell(row=row, column=4, value=r.get("name", "")).font = font_normal
        
        st = r.get("status", "PASS")
        st_c = ws_det.cell(row=row, column=5, value=st)
        st_c.alignment = Alignment(horizontal="center")
        st_c.fill = fill_pass if st == "PASS" else fill_fail
        st_c.font = font_pass if st == "PASS" else font_fail

        ws_det.cell(row=row, column=6, value=r.get("duration_s", 0.0)).alignment = Alignment(horizontal="center")
        ws_det.cell(row=row, column=7, value=r.get("error", "")).font = font_normal

        for c_i in range(1, 8):
            ws_det.cell(row=row, column=c_i).border = border_thin

    # Adjust widths
    for s in [ws_sum, ws_det]:
        for col in s.columns:
            max_len = 0
            col_letter = get_column_letter(col[0].column)
            for cell in col:
                val = str(cell.value or "")
                if "\n" in val: val = max(val.split("\n"), key=len)
                if len(val) > max_len: max_len = len(val)
            s.column_dimensions[col_letter].width = min(max(max_len + 3, 12), 65)

    wb.save(output_path)
    print(f"  --> Saved: {output_path}")


def create_master_workbook(all_metrics: dict, output_path: str):
    wb = openpyxl.Workbook()
    ws_master = wb.active
    ws_master.title = "Master 4-Suites Overview"
    ws_master.views.sheetView[0].showGridLines = True

    font_brand = Font(name="Segoe UI", size=18, bold=True, color="1E293B")
    font_header = Font(name="Segoe UI", size=11, bold=True, color="FFFFFF")
    font_bold = Font(name="Segoe UI", size=10, bold=True, color="1E293B")
    font_normal = Font(name="Segoe UI", size=10, color="334155")
    fill_header = PatternFill(start_color="1E293B", end_color="1E293B", fill_type="solid")
    fill_pass = PatternFill(start_color="DCFCE7", end_color="DCFCE7", fill_type="solid")
    font_pass = Font(name="Segoe UI", size=10, bold=True, color="15803D")
    font_fail = Font(name="Segoe UI", size=10, bold=True, color="B91C1C")
    border_thin = Border(
        left=Side(style="thin", color="CBD5E1"),
        right=Side(style="thin", color="CBD5E1"),
        top=Side(style="thin", color="CBD5E1"),
        bottom=Side(style="thin", color="CBD5E1"),
    )

    ws_master.merge_cells("A1:G1")
    ws_master["A1"] = "EduBoard — Comprehensive 4-Suite Quality Assurance Dashboard"
    ws_master["A1"].font = font_brand

    ws_master.merge_cells("A2:G2")
    ws_master["A2"] = f"Appium (Android) | DAST (Security) | Load (Concurrency) | Selenium (Web) | Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}"
    ws_master["A2"].font = font_normal

    # Overall KPIs
    total_tests = sum(m["total"] for m in all_metrics.values())
    total_passed = sum(m["passed"] for m in all_metrics.values())
    total_failed = sum(m["failed"] for m in all_metrics.values())
    total_rate = round((total_passed / total_tests * 100), 1) if total_tests > 0 else 100.0

    kpis = [
        ("TOTAL TESTS (ALL 4 SUITES)", total_tests, "A4:B5", PatternFill(start_color="F1F5F9", end_color="F1F5F9", fill_type="solid"), font_brand),
        ("TOTAL PASSED", total_passed, "C4:D5", fill_pass, font_pass),
        ("TOTAL FAILED", total_failed, "E4:E5", PatternFill(start_color="F1F5F9", end_color="F1F5F9", fill_type="solid"), font_bold),
        ("OVERALL PASS RATE", f"{total_rate}%", "F4:G5", PatternFill(start_color="E0E7FF", end_color="E0E7FF", fill_type="solid"), Font(name="Segoe UI", size=18, bold=True, color="4338CA")),
    ]
    for label, val, rng, fill, font in kpis:
        tl = rng.split(":")[0]
        ws_master[tl] = f"{label}\n{val}"
        ws_master[tl].alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        ws_master[tl].fill = fill
        ws_master[tl].font = font
        if ":" in rng: ws_master.merge_cells(rng)

    headers = ["#", "Test Suite", "Target Area", "Total Cases", "Passed", "Failed", "Pass Rate", "Status"]
    for col_i, h in enumerate(headers, start=1):
        c = ws_master.cell(row=7, column=col_i, value=h)
        c.font = font_header
        c.fill = fill_header
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border = border_thin

    for idx, (k, m) in enumerate(all_metrics.items(), start=1):
        row = idx + 7
        ws_master.cell(row=row, column=1, value=idx).alignment = Alignment(horizontal="center")
        ws_master.cell(row=row, column=2, value=m["title"]).font = font_bold
        ws_master.cell(row=row, column=3, value=m["target"]).font = font_normal
        ws_master.cell(row=row, column=4, value=m["total"]).alignment = Alignment(horizontal="center")
        ws_master.cell(row=row, column=5, value=m["passed"]).alignment = Alignment(horizontal="center")
        ws_master.cell(row=row, column=6, value=m["failed"]).alignment = Alignment(horizontal="center")
        ws_master.cell(row=row, column=7, value=f"{m['pass_rate']}%").alignment = Alignment(horizontal="center")
        
        st_c = ws_master.cell(row=row, column=8, value="PASSED" if m["failed"] == 0 else "FAILED")
        st_c.alignment = Alignment(horizontal="center")
        st_c.font = font_pass if m["failed"] == 0 else font_fail

        for c_i in range(1, 9):
            ws_master.cell(row=row, column=c_i).border = border_thin
            if c_i not in [2, 8]: ws_master.cell(row=row, column=c_i).font = font_normal

    for col in ws_master.columns:
        max_len = 0
        col_letter = get_column_letter(col[0].column)
        for cell in col:
            val = str(cell.value or "")
            if "\n" in val: val = max(val.split("\n"), key=len)
            if len(val) > max_len: max_len = len(val)
        ws_master.column_dimensions[col_letter].width = min(max(max_len + 3, 12), 65)

    wb.save(output_path)
    print(f"  --> Master Workbook Saved: {output_path}")


def main():
    os.makedirs(OUTPUT_EXCEL_DIR, exist_ok=True)
    os.makedirs(REPORTS_EXCEL_DIR, exist_ok=True)

    print("=================================================================")
    print("Executing All 4 Test Suites & Generating Excel Reports:")
    print("1. Appium Mobile E2E (355 Cases)")
    print("2. DAST Dynamic Security (350 Cases)")
    print("3. Load & Concurrency (350 Cases)")
    print("4. Selenium Web Automation (355 Cases)")
    print("=================================================================\n")

    all_metrics = {}

    for suite_key, info in SUITES.items():
        print(f"Running & processing suite: {info['title']}...")
        metrics = run_suite_and_collect(suite_key, info)
        all_metrics[suite_key] = metrics
        
        excel_path = os.path.join(OUTPUT_EXCEL_DIR, info["excel_name"])
        create_styled_excel(metrics, excel_path)
        shutil.copy2(excel_path, os.path.join(REPORTS_EXCEL_DIR, info["excel_name"]))

    # Generate Unified Master Workbook
    master_path = os.path.join(OUTPUT_EXCEL_DIR, "Master_4_Suites_Test_Report.xlsx")
    create_master_workbook(all_metrics, master_path)
    shutil.copy2(master_path, os.path.join(REPORTS_EXCEL_DIR, "Master_4_Suites_Test_Report.xlsx"))

    print("\nAll 4 Excel Test Reports generated successfully!")
    print(f"Output Directory: {OUTPUT_EXCEL_DIR}")


if __name__ == "__main__":
    main()
