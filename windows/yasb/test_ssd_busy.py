"""Tests for the YASB SSD saturation widget helper.

Run from the repository root:

    py -B -m unittest discover -s windows/yasb -p "test_*.py" -v

The helper is imported as a module (it lives next to this file); every check goes
through its public functions, never through internal helpers.
"""

from __future__ import annotations

import json
import unittest

import ssd_busy as ssd


class ClampPercentTest(unittest.TestCase):
    def test_keeps_a_normal_reading(self):
        self.assertAlmostEqual(ssd.clamp_percent(42.5), 42.5)

    def test_caps_queued_io_at_one_hundred(self):
        # Windows counts service time per request, so overlapping I/O can push the
        # raw counter past the wall clock; Task Manager clamps it and so do we.
        self.assertEqual(ssd.clamp_percent(1800.0), 100.0)

    def test_never_goes_negative_when_the_counters_reset(self):
        self.assertEqual(ssd.clamp_percent(-20.0), 0.0)

    def test_a_missing_reading_falls_back_to_zero(self):
        self.assertEqual(ssd.clamp_percent(float("nan")), 0.0)


class LabelTest(unittest.TestCase):
    def test_label_reuses_the_pi_agents_small_caps_span(self):
        label = ssd.format_label(64.8)
        self.assertIn("font-size:9px; letter-spacing:1px", label)
        self.assertIn(">SSD</font>", label)
        self.assertIn("64.8%", label)

    def test_the_word_is_muted_and_only_the_word_carries_a_colour(self):
        label = ssd.format_label(0.0)
        self.assertIn('color="#9aa3b2"', label)
        self.assertNotIn("<font", label.split("</font>", 1)[1])

    def test_the_number_is_clamped_before_it_reaches_the_bar(self):
        self.assertIn("100.0%", ssd.format_label(1800.0))

    def test_payload_is_a_json_document_the_bar_can_read(self):
        payload = json.loads(ssd.payload(12.34))
        self.assertIsInstance(payload, str)
        self.assertIn("12.3%", payload)

    def test_error_payload_names_the_widget_so_it_never_disappears(self):
        self.assertIn("SSD", ssd.error_payload())


class SamplerTest(unittest.TestCase):
    def test_samples_a_percentage_inside_the_valid_range(self):
        value = ssd.sample_busy_percent(window_ms=300)
        self.assertGreaterEqual(value, 0.0)
        self.assertLessEqual(value, 100.0)


if __name__ == "__main__":
    unittest.main()
