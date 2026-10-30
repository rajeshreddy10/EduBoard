"""
EduBoard Selenium Test Helpers
Provides utility functions, explicit waits, and screenshot capture.
"""
import os
import time
from datetime import datetime
try:
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.common.by import By
    from selenium.common.exceptions import TimeoutException, NoSuchElementException
except ImportError:
    WebDriverWait = None
    EC = None
    class By:
        CSS_SELECTOR = "css selector"
    TimeoutException = Exception
    NoSuchElementException = Exception

SCREENSHOT_DIR = os.path.join(os.path.dirname(__file__), '..', 'screenshots')
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

DEFAULT_TIMEOUT = 15


def wait_for_element(driver, locator, timeout=DEFAULT_TIMEOUT):
    """Wait for element to be visible and return it."""
    try:
        return WebDriverWait(driver, timeout).until(
            EC.visibility_of_element_located(locator)
        )
    except TimeoutException:
        take_screenshot(driver, f"timeout_{locator[1][:30]}")
        raise


def wait_for_clickable(driver, locator, timeout=DEFAULT_TIMEOUT):
    """Wait for element to be clickable and return it."""
    try:
        return WebDriverWait(driver, timeout).until(
            EC.element_to_be_clickable(locator)
        )
    except TimeoutException:
        take_screenshot(driver, f"not_clickable_{locator[1][:30]}")
        raise


def wait_for_url_contains(driver, partial_url, timeout=DEFAULT_TIMEOUT):
    """Wait for URL to contain a specific string."""
    try:
        WebDriverWait(driver, timeout).until(
            EC.url_contains(partial_url)
        )
    except TimeoutException:
        take_screenshot(driver, f"url_timeout_{partial_url[:20]}")
        raise


def wait_for_text_in_element(driver, locator, text, timeout=DEFAULT_TIMEOUT):
    """Wait for element to contain specific text."""
    try:
        return WebDriverWait(driver, timeout).until(
            EC.text_to_be_present_in_element(locator, text)
        )
    except TimeoutException:
        take_screenshot(driver, f"text_timeout_{text[:20]}")
        raise


def is_element_present(driver, locator, timeout=5):
    """Check if element is present without raising exception."""
    try:
        WebDriverWait(driver, timeout).until(
            EC.presence_of_element_located(locator)
        )
        return True
    except (TimeoutException, NoSuchElementException):
        return False


def take_screenshot(driver, name="screenshot"):
    """Capture screenshot with timestamp."""
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = os.path.join(SCREENSHOT_DIR, f"{name}_{ts}.png")
    try:
        driver.save_screenshot(filename)
        return filename
    except Exception:
        return None


def safe_click(driver, locator, timeout=DEFAULT_TIMEOUT):
    """Safe click with explicit wait."""
    element = wait_for_clickable(driver, locator, timeout)
    element.click()
    return element


def safe_type(driver, locator, text, clear_first=True, timeout=DEFAULT_TIMEOUT):
    """Type text into element with explicit wait."""
    element = wait_for_element(driver, locator, timeout)
    if clear_first:
        element.clear()
    element.send_keys(text)
    return element


def scroll_to_element(driver, element):
    """Scroll element into view."""
    driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", element)
    time.sleep(0.3)


def get_element_text(driver, locator, timeout=DEFAULT_TIMEOUT):
    """Get text content of an element."""
    element = wait_for_element(driver, locator, timeout)
    return element.text.strip()


def wait_for_page_load(driver, timeout=DEFAULT_TIMEOUT):
    """Wait for page to fully load."""
    WebDriverWait(driver, timeout).until(
        lambda d: d.execute_script("return document.readyState") == "complete"
    )


def assert_page_title_contains(driver, expected_text):
    """Assert page title contains expected text."""
    assert expected_text.lower() in driver.title.lower(), \
        f"Expected '{expected_text}' in title '{driver.title}'"


def assert_element_visible(driver, locator, timeout=DEFAULT_TIMEOUT):
    """Assert element is visible."""
    element = wait_for_element(driver, locator, timeout)
    assert element.is_displayed(), f"Element {locator} is not visible"
    return element


def assert_element_text(driver, locator, expected_text, timeout=DEFAULT_TIMEOUT):
    """Assert element contains expected text."""
    element = wait_for_element(driver, locator, timeout)
    actual = element.text.strip()
    assert expected_text in actual, f"Expected '{expected_text}' in '{actual}'"
    return element


def assert_url_path(driver, expected_path):
    """Assert current URL path matches expected."""
    from urllib.parse import urlparse
    current_path = urlparse(driver.current_url).path
    assert expected_path in current_path, \
        f"Expected path '{expected_path}' but got '{current_path}'"

