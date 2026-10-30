"""Page Objects for EduBoard web application Selenium tests."""
try:
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.common.exceptions import TimeoutException
except ImportError:
    class By:
        CSS_SELECTOR = "css selector"
    WebDriverWait = None
    EC = None
    TimeoutException = Exception
from tests.selenium.utils.helpers import (
    wait_for_element, wait_for_clickable, safe_click, safe_type,
    is_element_present, wait_for_url_contains, wait_for_page_load,
    take_screenshot
)


class LoginPage:
    PATH = "/login"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def enter_email(self, email):
        safe_type(self.driver, (By.CSS_SELECTOR, "input[type='email'], input[name='email']"), email)

    def enter_password(self, password):
        safe_type(self.driver, (By.CSS_SELECTOR, "input[type='password']"), password)

    def click_login(self):
        safe_click(self.driver, (By.CSS_SELECTOR, "button[type='submit']"))

    def get_error_message(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "[role='alert'], .error, [class*='error']"), timeout=5)
            return el.text
        except TimeoutException:
            return ""

    def is_on_login_page(self):
        return "/login" in self.driver.current_url

    def click_signup_link(self):
        safe_click(self.driver, (By.CSS_SELECTOR, "a[href*='signup'], a[href*='register']"))

    def click_forgot_password(self):
        safe_click(self.driver, (By.CSS_SELECTOR, "a[href*='forgot'], a[href*='reset']"))

    def is_email_field_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "input[type='email'], input[name='email']"))

    def is_password_field_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "input[type='password']"))

    def is_submit_button_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "button[type='submit']"))

    def get_page_heading(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "h1, h2, [class*='title']"), timeout=5)
            return el.text
        except TimeoutException:
            return ""


class SignupPage:
    PATH = "/signup"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def enter_name(self, name):
        try:
            safe_type(self.driver, (By.CSS_SELECTOR, "input[name='name'], input[placeholder*='name' i]"), name)
        except Exception:
            pass

    def enter_email(self, email):
        safe_type(self.driver, (By.CSS_SELECTOR, "input[type='email'], input[name='email']"), email)

    def enter_password(self, password):
        fields = self.driver.find_elements(By.CSS_SELECTOR, "input[type='password']")
        if fields:
            fields[0].clear()
            fields[0].send_keys(password)

    def enter_confirm_password(self, password):
        fields = self.driver.find_elements(By.CSS_SELECTOR, "input[type='password']")
        if len(fields) > 1:
            fields[1].clear()
            fields[1].send_keys(password)

    def click_signup(self):
        safe_click(self.driver, (By.CSS_SELECTOR, "button[type='submit']"))

    def get_error_message(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "[role='alert'], .error, [class*='error']"), timeout=5)
            return el.text
        except TimeoutException:
            return ""

    def is_on_signup_page(self):
        return "/signup" in self.driver.current_url

    def click_login_link(self):
        safe_click(self.driver, (By.CSS_SELECTOR, "a[href*='login']"))

    def is_name_field_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "input[name='name'], input[placeholder*='name' i]"), timeout=5)

    def is_email_field_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "input[type='email'], input[name='email']"))

    def is_password_field_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "input[type='password']"))

    def is_submit_button_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "button[type='submit']"))


class ForgotPasswordPage:
    PATH = "/forgot-password"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def enter_email(self, email):
        safe_type(self.driver, (By.CSS_SELECTOR, "input[type='email'], input[name='email']"), email)

    def click_submit(self):
        safe_click(self.driver, (By.CSS_SELECTOR, "button[type='submit']"))

    def get_success_message(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "[class*='success'], [role='status']"), timeout=5)
            return el.text
        except TimeoutException:
            return ""

    def get_error_message(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "[role='alert'], .error, [class*='error']"), timeout=5)
            return el.text
        except TimeoutException:
            return ""

    def is_email_field_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "input[type='email']"))


class DashboardPage:
    PATH = "/dashboard"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_dashboard(self):
        return "/dashboard" in self.driver.current_url

    def get_page_heading(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "h1, h2, [class*='title']"), timeout=5)
            return el.text
        except TimeoutException:
            return self.driver.title

    def click_boards_nav(self):
        try:
            safe_click(self.driver, (By.CSS_SELECTOR, "a[href*='boards'], nav a[href*='board']"))
        except Exception:
            pass

    def click_create_board(self):
        try:
            safe_click(self.driver, (By.CSS_SELECTOR, "a[href*='create'], button[class*='create']"))
        except Exception:
            pass

    def get_nav_items(self):
        try:
            items = self.driver.find_elements(By.CSS_SELECTOR, "nav a, aside a, [class*='nav'] a")
            return [i.text for i in items if i.text.strip()]
        except Exception:
            return []

    def is_sidebar_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "aside, nav, [class*='sidebar']"), timeout=5)

    def is_user_avatar_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "[class*='avatar'], [class*='user'], img[alt*='user' i]"), timeout=5)


class BoardsPage:
    PATH = "/dashboard/boards"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_boards_page(self):
        return "boards" in self.driver.current_url

    def get_board_count(self):
        try:
            cards = self.driver.find_elements(By.CSS_SELECTOR, "[class*='board-card'], [class*='card'], article")
            return len(cards)
        except Exception:
            return 0

    def click_create_board(self):
        try:
            safe_click(self.driver, (By.CSS_SELECTOR, "a[href*='create'], button[class*='create'], [class*='new']"))
        except Exception:
            pass

    def is_empty_state_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "[class*='empty'], [class*='no-board']"), timeout=5)

    def get_board_titles(self):
        try:
            titles = self.driver.find_elements(By.CSS_SELECTOR, "[class*='board'] h2, [class*='board'] h3, [class*='card'] h2, [class*='card'] h3")
            return [t.text for t in titles if t.text.strip()]
        except Exception:
            return []


class DrawSpacePage:
    PATH = "/normal-board"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_drawspace(self):
        return "normal-board" in self.driver.current_url

    def is_canvas_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "canvas, svg, [class*='canvas']"), timeout=10)

    def is_toolbar_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "[class*='toolbar'], [class*='tool-bar']"), timeout=10)

    def is_save_button_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "button[class*='save'], button:contains('Save')"), timeout=5)

    def click_save(self):
        try:
            buttons = self.driver.find_elements(By.CSS_SELECTOR, "button")
            for btn in buttons:
                if "save" in btn.text.lower() or "Save" in btn.text:
                    btn.click()
                    return True
        except Exception:
            pass
        return False

    def get_header_title(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "h1, header h2, [class*='title']"), timeout=5)
            return el.text
        except TimeoutException:
            return ""

    def is_header_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "header"), timeout=10)

    def is_reference_button_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "button, [class*='reference']"), timeout=5)


class DocCanvasPage:
    PATH = "/gesture-board"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_doccanvas(self):
        return "gesture-board" in self.driver.current_url

    def is_canvas_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "canvas, svg, [class*='canvas']"), timeout=10)

    def is_toolbar_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "[class*='toolbar'], [class*='tool']"), timeout=10)

    def is_header_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "header"), timeout=10)

    def is_open_document_button_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "label, button, [class*='open']"), timeout=5)

    def click_save(self):
        try:
            buttons = self.driver.find_elements(By.CSS_SELECTOR, "button")
            for btn in buttons:
                if "save" in btn.text.lower():
                    btn.click()
                    return True
        except Exception:
            pass
        return False

    def get_header_title(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "h1, header span, [class*='title']"), timeout=5)
            return el.text
        except TimeoutException:
            return ""


class VoiceBoardPage:
    PATH = "/voice-control"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_voiceboard(self):
        return "voice-control" in self.driver.current_url

    def is_header_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "header"), timeout=10)

    def is_canvas_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "canvas, svg, [class*='canvas']"), timeout=10)

    def is_voice_controls_present(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "button, [class*='voice'], [class*='mic']"), timeout=5)

    def get_header_title(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "h1, header span, [class*='title']"), timeout=5)
            return el.text
        except TimeoutException:
            return ""

    def click_save(self):
        try:
            buttons = self.driver.find_elements(By.CSS_SELECTOR, "button")
            for btn in buttons:
                if "save" in btn.text.lower():
                    btn.click()
                    return True
        except Exception:
            pass
        return False


class ProfilePage:
    PATH = "/profile"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_profile(self):
        return "/profile" in self.driver.current_url

    def is_page_loaded(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "main, [class*='profile'], [class*='content']"), timeout=10)

    def get_page_heading(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "h1, h2"), timeout=5)
            return el.text
        except TimeoutException:
            return ""


class SettingsPage:
    PATH = "/settings"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_settings(self):
        return "/settings" in self.driver.current_url

    def is_page_loaded(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "main, [class*='settings'], [class*='content']"), timeout=10)

    def get_page_heading(self):
        try:
            el = wait_for_element(self.driver, (By.CSS_SELECTOR, "h1, h2"), timeout=5)
            return el.text
        except TimeoutException:
            return ""


class HelpPage:
    PATH = "/help"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_help(self):
        return "/help" in self.driver.current_url

    def is_page_loaded(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "main, [class*='help'], h1"), timeout=10)


class NotificationsPage:
    PATH = "/notifications"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_notifications(self):
        return "/notifications" in self.driver.current_url

    def is_page_loaded(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "main, [class*='notification'], h1"), timeout=10)


class OnboardingPage:
    PATH = "/onboarding"

    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def navigate(self):
        self.driver.get(f"{self.base_url}{self.PATH}")
        wait_for_page_load(self.driver)

    def is_on_onboarding(self):
        return "/onboarding" in self.driver.current_url

    def is_page_loaded(self):
        return is_element_present(self.driver, (By.CSS_SELECTOR, "main, [class*='onboard'], h1, h2"), timeout=10)

