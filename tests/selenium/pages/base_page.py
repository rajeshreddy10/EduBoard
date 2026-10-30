"""Base Page Object for Selenium tests."""
from selenium.webdriver.common.by import By
from tests.selenium.utils.helpers import (
    wait_for_element, wait_for_clickable, wait_for_url_contains,
    safe_click, safe_type, take_screenshot, is_element_present,
    wait_for_page_load
)


class BasePage:
    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate_to(self, path=""):
        self.driver.get(f"{self.base_url}{path}")
        wait_for_page_load(self.driver)

    def get_page_title(self):
        return self.driver.title

    def get_current_url(self):
        return self.driver.current_url

    def take_screenshot(self, name="page"):
        return take_screenshot(self.driver, name)

    def is_element_present(self, locator, timeout=5):
        return is_element_present(self.driver, locator, timeout)

    def click(self, locator):
        return safe_click(self.driver, locator)

    def type_text(self, locator, text):
        return safe_type(self.driver, locator, text)

    def get_text(self, locator):
        from tests.selenium.utils.helpers import get_element_text
        return get_element_text(self.driver, locator)

    def wait_for_element(self, locator, timeout=15):
        return wait_for_element(self.driver, locator, timeout)

