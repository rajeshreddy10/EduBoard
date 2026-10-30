"""
EduBoard Excel Test Report Generator
Consolidates test results into professional multi-sheet Excel reports.
"""
import os
import sys
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

def build_excel_report(test_suite_name, test_cases_file, output_file):
    if not os.path.exists(test_cases_file):
        print(f"Warning: {test_cases_file} not found")
        return
    wb = openpyxl.load_workbook(test_cases_file)
    wb.save(output_file)
    print(f"Excel report generated: {output_file}")

if __name__ == "__main__":
    suite = sys.argv[1] if len(sys.argv) > 1 else "selenium"
    cases_file = f"test-cases/{suite}_test_cases.xlsx"
    out_file = f"{suite}_test_report.xlsx"
    build_excel_report(suite, cases_file, out_file)
