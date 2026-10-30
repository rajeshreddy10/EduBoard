"""
EduBoard Locust Load & Performance Test Plan
Simulates Student, Teacher, and Collaborator concurrency across all endpoints.
"""
from locust import HttpUser, task, between

class EduBoardUser(HttpUser):
    wait_time = between(0.5, 2.0)

    @task(5)
    def test_landing_and_login(self):
        self.client.get("/")
        self.client.get("/login")

    @task(3)
    def test_auth_pages(self):
        self.client.get("/signup")
        self.client.get("/forgot-password")

    @task(4)
    def test_dashboard_boards(self):
        self.client.get("/dashboard")
        self.client.get("/dashboard/boards")

    @task(6)
    def test_drawspace_canvas(self):
        self.client.get("/normal-board")

    @task(4)
    def test_doccanvas_studio(self):
        self.client.get("/gesture-board")

    @task(3)
    def test_voice_board(self):
        self.client.get("/voice-control")

    @task(2)
    def test_profile_and_settings(self):
        self.client.get("/profile")
        self.client.get("/settings")

    @task(2)
    def test_help_and_notifications(self):
        self.client.get("/help")
        self.client.get("/help/faq")
        self.client.get("/notifications")
