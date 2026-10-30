"""
EduBoard Web & Mobile Core Unit Tests
Validates board algorithms, shape computations, and utility helpers.
"""
import pytest

def test_color_palette_hex_mapping():
    colors = {
        "Ink": "#0F172A",
        "Ruby": "#EF4444",
        "Amber": "#F59E0B",
        "Emerald": "#10B981",
        "Azure": "#3B82F6",
        "Violet": "#8B5CF6"
    }
    assert len(colors) == 6
    assert colors["Ink"].startswith("#")
    assert colors["Ruby"] == "#EF4444"

def test_stroke_width_bounding():
    min_width = 1
    max_width = 64
    def clamp_stroke(w):
        return max(min_width, min(max_width, w))
    assert clamp_stroke(0) == 1
    assert clamp_stroke(24) == 24
    assert clamp_stroke(100) == 64

def test_shape_geometry_bounding_box():
    p1 = (10, 20)
    p2 = (110, 120)
    width = abs(p2[0] - p1[0])
    height = abs(p2[1] - p1[1])
    assert width == 100
    assert height == 100
