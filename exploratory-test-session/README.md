# Exploratory Test Session Evidence

This directory contains all screenshot evidence captured during the 10-minute time-boxed exploratory testing session conducted on 2025-11-04.

## Session Overview

- **Duration:** 10 minutes (strictly time-boxed)
- **Tester Role:** QA Engineer (2 years experience perspective)
- **Focus:** User experience, critical workflows, intentional and unintentional bugs
- **Screenshots Captured:** 10 sequential evidence files

## Screenshot Inventory

| Step | Filename | Description | Key Observations |
|------|----------|-------------|------------------|
| 01 | `step01_login_page.png` | Initial login screen | Test account credentials displayed clearly |
| 02 | `step02_invalid_login.png` | Invalid login error | Clear error message, no security leak |
| 03 | `step03_products_list.png` | Product list (8 items) | Stock status colors visible (red/yellow for low stock) |
| 04 | `step04_intentional_bug_500_error.png` | "バグ票" search error | 500 error with exposed internal message |
| 05 | `step05_new_product_form.png` | New product form | Validation hints displayed (1-50 chars, etc.) |
| 06 | `step06_xss_test_input.png` | XSS payload input | Script tag entered in description field |
| 07 | `step07_edit_page_xss.png` | Edit page with XSS | Stored payload visible in textarea (not executed) |
| 08 | `step08_before_delete.png` | Before deletion (9 items) | Product list showing XSS test product |
| 09 | `step09_after_instant_delete.png` | After instant delete (8 items) | Product deleted without confirmation |
| 10 | `step10_logout_405_error.png` | Logout 405 error | Method Not Allowed - unintentional bug |

## Bug Evidence Mapping

### Bug #1: Delete Without Confirmation
- **Evidence:** step08_before_delete.png, step09_after_instant_delete.png
- **Demonstrates:** Product count changes from 9 to 8 instantly without confirmation dialog
- **Status:** Intentional bug (documented in README)

### Bug #2: Logout 405 Error
- **Evidence:** step10_logout_405_error.png
- **Demonstrates:** Logout button triggers HTTP 405 Method Not Allowed
- **Status:** Unintentional bug (not documented, likely method mismatch)

### Bug #3: "バグ票" 500 Error Trigger
- **Evidence:** step04_intentional_bug_500_error.png
- **Demonstrates:** Search keyword triggers 500 error with internal message
- **Status:** Intentional bug (documented as "Easter egg")

### Bug #4: XSS Vulnerability
- **Evidence:** step06_xss_test_input.png, step07_edit_page_xss.png
- **Demonstrates:** Script tags stored without sanitization
- **Status:** Intentional bug (documented security vulnerability)

## Visual Test Coverage

### Decision Table Validation (Stock Status)
- **Evidence:** step03_products_list.png
- **Validated Cases:**
  - 0 stock = Red background ("在庫切れ")
  - 1-10 stock = Yellow background ("残りわずか")
  - 11+ stock = Normal ("在庫あり")

### State Transition Testing
- **Evidence:** step07_edit_page_xss.png
- **Validated Transition:** 準備中 (Preparing) → 公開中 (Public)
- **UI Guidance:** State transition rules displayed on edit page

### Form Validation
- **Evidence:** step05_new_product_form.png
- **Observations:**
  - Inline hints for all validation rules
  - Required fields marked with asterisk
  - Status locked to "準備中" for new products

## Screenshot Quality

- **Resolution:** Full viewport (1280x720 typical)
- **Format:** PNG (lossless)
- **Total Size:** ~388 KB for 10 screenshots
- **Capture Method:** Playwright browser automation

## Related Documentation

- **Full English Report:** `../EXPLORATORY_TEST_REPORT.md` (19.5 KB)
- **Japanese Summary:** `../探索的テスト実施報告書.md` (19 KB)
- **Test Notes:** Chronological timeline included in both reports

## Usage Instructions

These screenshots serve as:
1. **Evidence** for bug reports and regression tracking
2. **Reference** for understanding application behavior
3. **Training material** for QA practice and test technique learning
4. **Baseline** for visual regression testing

To view the complete analysis and context for each screenshot, refer to the full test reports in the parent directory.

---

**Session Date:** 2025-11-04  
**Capture Tool:** Playwright  
**Browser:** Chromium  
**Total Evidence Files:** 10 PNG images
