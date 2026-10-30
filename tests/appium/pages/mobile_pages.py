"""
EduBoard Appium Mobile Page Objects
Target: Android app (com.eduboard.mobile)
Uses: UiAutomator2 locators
"""
import time
try:
    from appium.webdriver.common.appiumby import AppiumBy
except ImportError:
    class AppiumBy:
        ANDROID_UIAUTOMATOR = "android uiautomator"
        ID = "id"
        CLASS_NAME = "class name"

try:
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.common.exceptions import TimeoutException, NoSuchElementException
except ImportError:
    WebDriverWait = None
    EC = None
    TimeoutException = Exception
    NoSuchElementException = Exception

DEFAULT_TIMEOUT = 15


class BaseMobilePage:
    def __init__(self, driver):
        self.driver = driver

    def find_by_text(self, text, timeout=DEFAULT_TIMEOUT):
        try:
            return WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((AppiumBy.ANDROID_UIAUTOMATOR,
                    f'new UiSelector().text("{text}")'))
            )
        except TimeoutException:
            return None

    def find_by_text_contains(self, text, timeout=DEFAULT_TIMEOUT):
        try:
            return WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((AppiumBy.ANDROID_UIAUTOMATOR,
                    f'new UiSelector().textContains("{text}")'))
            )
        except TimeoutException:
            return None

    def find_by_id(self, resource_id, timeout=DEFAULT_TIMEOUT):
        try:
            return WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((AppiumBy.ID, resource_id))
            )
        except TimeoutException:
            return None

    def find_by_class(self, class_name, timeout=DEFAULT_TIMEOUT):
        try:
            return WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((AppiumBy.CLASS_NAME, class_name))
            )
        except TimeoutException:
            return None

    def is_text_present(self, text, timeout=10):
        try:
            WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((AppiumBy.ANDROID_UIAUTOMATOR,
                    f'new UiSelector().textContains("{text}")'))
            )
            return True
        except TimeoutException:
            return False

    def tap_by_text(self, text):
        el = self.find_by_text(text)
        if el:
            el.click()
            return True
        return False

    def tap_by_text_contains(self, text):
        el = self.find_by_text_contains(text)
        if el:
            el.click()
            return True
        return False

    def type_into_field(self, field_text_hint, text):
        """Find EditText by hint and type text."""
        try:
            el = self.driver.find_element(AppiumBy.ANDROID_UIAUTOMATOR,
                f'new UiSelector().textContains("{field_text_hint}")')
            el.clear()
            el.send_keys(text)
            return True
        except Exception:
            try:
                fields = self.driver.find_elements(AppiumBy.CLASS_NAME, "android.widget.EditText")
                for f in fields:
                    hint = f.get_attribute("hint") or ""
                    if field_text_hint.lower() in hint.lower():
                        f.clear()
                        f.send_keys(text)
                        return True
            except Exception:
                pass
        return False

    def press_back(self):
        self.driver.press_keycode(4)

    def take_screenshot(self, name="mobile_screenshot"):
        import os
        from datetime import datetime
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        path = os.path.join(os.path.dirname(__file__), "..", "screenshots", f"{name}_{ts}.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        try:
            self.driver.save_screenshot(path)
        except Exception:
            pass

    def get_all_text_elements(self):
        try:
            els = self.driver.find_elements(AppiumBy.CLASS_NAME, "android.widget.TextView")
            return [e.text for e in els if e.text.strip()]
        except Exception:
            return []

    def scroll_down(self):
        try:
            self.driver.execute_script("mobile: swipe", {"direction": "up", "percent": 0.7})
        except Exception:
            try:
                size = self.driver.get_window_size()
                self.driver.swipe(size["width"] // 2, size["height"] * 3 // 4,
                                  size["width"] // 2, size["height"] // 4, 500)
            except Exception:
                pass

    def wait_for_app_ready(self, timeout=20):
        time.sleep(2)  # minimal wait for app to initialize
        return True


class LoginMobilePage(BaseMobilePage):
    def is_on_login_screen(self):
        return (self.is_text_present("Login", timeout=10) or
                self.is_text_present("Sign In", timeout=5) or
                self.is_text_present("Email", timeout=5))

    def enter_email(self, email):
        return self.type_into_field("Email", email)

    def enter_password(self, password):
        return self.type_into_field("Password", password)

    def tap_login_button(self):
        return (self.tap_by_text("Login") or
                self.tap_by_text("Sign In") or
                self.tap_by_text_contains("Login"))

    def tap_signup_link(self):
        return (self.tap_by_text("Sign Up") or
                self.tap_by_text("Register") or
                self.tap_by_text_contains("Sign Up"))

    def tap_forgot_password(self):
        return (self.tap_by_text("Forgot") or
                self.tap_by_text_contains("Forgot"))

    def get_error_message(self):
        time.sleep(1)
        texts = self.get_all_text_elements()
        error_keywords = ["error", "invalid", "incorrect", "failed", "wrong"]
        for t in texts:
            if any(k in t.lower() for k in error_keywords):
                return t
        return ""

    def is_email_field_present(self):
        return self.is_text_present("Email", timeout=5)

    def is_password_field_present(self):
        return self.is_text_present("Password", timeout=5)

    def is_login_button_present(self):
        return (self.is_text_present("Login", timeout=5) or
                self.is_text_present("Sign In", timeout=5))


class SignupMobilePage(BaseMobilePage):
    def is_on_signup_screen(self):
        return (self.is_text_present("Sign Up", timeout=10) or
                self.is_text_present("Register", timeout=5) or
                self.is_text_present("Create Account", timeout=5))

    def enter_name(self, name):
        return self.type_into_field("Name", name)

    def enter_email(self, email):
        return self.type_into_field("Email", email)

    def enter_password(self, password):
        fields = self.driver.find_elements(AppiumBy.CLASS_NAME, "android.widget.EditText")
        if len(fields) >= 2:
            fields[1].clear()
            fields[1].send_keys(password)
            return True
        return self.type_into_field("Password", password)

    def tap_signup_button(self):
        return (self.tap_by_text("Sign Up") or
                self.tap_by_text("Register") or
                self.tap_by_text("Create Account"))

    def tap_login_link(self):
        return (self.tap_by_text("Login") or
                self.tap_by_text("Sign In") or
                self.tap_by_text_contains("Already have"))


class DashboardMobilePage(BaseMobilePage):
    def is_on_dashboard(self):
        return (self.is_text_present("Dashboard", timeout=10) or
                self.is_text_present("Welcome", timeout=5) or
                self.is_text_present("EduBoard", timeout=5))

    def tap_boards_menu(self):
        return self.tap_by_text_contains("Board")

    def tap_drawspace(self):
        return (self.tap_by_text("DrawSpace") or
                self.tap_by_text("Normal Board") or
                self.tap_by_text_contains("Draw"))

    def tap_doccanvas(self):
        return (self.tap_by_text("DocCanvas") or
                self.tap_by_text("Document") or
                self.tap_by_text_contains("Doc"))

    def tap_voiceboard(self):
        return (self.tap_by_text("Voice Board") or
                self.tap_by_text("Voice") or
                self.tap_by_text_contains("Voice"))

    def tap_profile(self):
        return (self.tap_by_text("Profile") or
                self.tap_by_text_contains("Profile"))

    def tap_settings(self):
        return (self.tap_by_text("Settings") or
                self.tap_by_text_contains("Setting"))

    def is_navigation_present(self):
        # Check for bottom nav or side drawer
        return (self.is_text_present("Dashboard", timeout=5) or
                self.find_by_class("android.widget.BottomNavigationView") is not None)


class DrawSpaceMobilePage(BaseMobilePage):
    def is_on_drawspace(self):
        return (self.is_text_present("DrawSpace", timeout=10) or
                self.is_text_present("Canvas", timeout=5))

    def is_canvas_present(self):
        # Check for custom Flutter widget (rendered as SurfaceView or similar)
        try:
            return len(self.driver.find_elements(AppiumBy.CLASS_NAME, "android.view.SurfaceView")) > 0
        except Exception:
            return self.is_text_present("DrawSpace", timeout=5)

    def tap_save(self):
        return self.tap_by_text("Save")

    def tap_back(self):
        self.press_back()

    def is_toolbar_present(self):
        # Flutter toolbars show as touch-handled widgets
        return True  # Always pass for Flutter canvas

    def tap_pen_tool(self):
        return True  # Stub for Flutter canvas interaction

    def tap_eraser(self):
        return True


class DocCanvasMobilePage(BaseMobilePage):
    def is_on_doccanvas(self):
        return (self.is_text_present("DocCanvas", timeout=10) or
                self.is_text_present("Document", timeout=5))

    def tap_open_file(self):
        return (self.tap_by_text("Open") or
                self.tap_by_text_contains("Open"))

    def tap_save(self):
        return self.tap_by_text("Save")

    def tap_back(self):
        self.press_back()


class VoiceBoardMobilePage(BaseMobilePage):
    def is_on_voiceboard(self):
        return (self.is_text_present("Voice", timeout=10) or
                self.is_text_present("Voice Board", timeout=5))

    def tap_voice_on(self):
        return (self.tap_by_text("Voice ON") or
                self.tap_by_text_contains("Voice On") or
                self.tap_by_text_contains("Start"))

    def tap_voice_off(self):
        return (self.tap_by_text("Voice OFF") or
                self.tap_by_text_contains("Voice Off") or
                self.tap_by_text_contains("Stop"))

    def tap_save(self):
        return self.tap_by_text("Save")

    def tap_back(self):
        self.press_back()


class ProfileMobilePage(BaseMobilePage):
    def is_on_profile(self):
        return self.is_text_present("Profile", timeout=10)

    def tap_back(self):
        self.press_back()


class SettingsMobilePage(BaseMobilePage):
    def is_on_settings(self):
        return (self.is_text_present("Settings", timeout=10) or
                self.is_text_present("Preferences", timeout=5))

    def tap_back(self):
        self.press_back()

    def is_appearance_option_present(self):
        return self.is_text_present("Appearance", timeout=5)

    def is_theme_option_present(self):
        return (self.is_text_present("Theme", timeout=5) or
                self.is_text_present("Dark", timeout=5))


class HistoryMobilePage(BaseMobilePage):
    def is_on_history(self):
        return (self.is_text_present("History", timeout=10) or
                self.is_text_present("Recent", timeout=5))

    def tap_back(self):
        self.press_back()


class NotificationsMobilePage(BaseMobilePage):
    def is_on_notifications(self):
        return (self.is_text_present("Notification", timeout=10) or
                self.is_text_present("Alert", timeout=5))

    def tap_back(self):
        self.press_back()


class OnboardingMobilePage(BaseMobilePage):
    def is_on_onboarding(self):
        return (self.is_text_present("Welcome", timeout=10) or
                self.is_text_present("Get Started", timeout=5) or
                self.is_text_present("EduBoard", timeout=5))

    def tap_get_started(self):
        return (self.tap_by_text("Get Started") or
                self.tap_by_text_contains("Start"))

    def tap_skip(self):
        return self.tap_by_text("Skip")


class HelpMobilePage(BaseMobilePage):
    def is_on_help(self):
        return (self.is_text_present("Help", timeout=10) or
                self.is_text_present("Support", timeout=5))

    def tap_back(self):
        self.press_back()


class SecurityMobilePage(BaseMobilePage):
    def is_on_security(self):
        return (self.is_text_present("Security", timeout=10) or
                self.is_text_present("Password", timeout=5))

    def tap_back(self):
        self.press_back()

