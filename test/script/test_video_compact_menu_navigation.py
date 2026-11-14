"""Check the native compact menu's navigation command ordering."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class VideoCompactMenuNavigationTests(unittest.TestCase):
    def test_navigation_selection_runs_after_window_overlay_removal(self):
        source = (ROOT / 'ios/Runner/AppDelegate.swift').read_text()
        menu = source.split('private final class VideoCompactMenu: UIControl {', 1)[1]
        dismiss = menu.split('  func dismiss(animated: Bool = true) {', 1)[1]
        dismiss = dismiss.split('\n  deinit', 1)[0]
        immediate = dismiss.index('if let value, !waitsForDismissal { onChoose(value) }')
        finish = dismiss.index('let finish =')
        removal = dismiss.index('removeFromSuperview()', finish)
        closed = dismiss.index('closed()', removal)
        deferred = dismiss.index('if let value, waitsForDismissal { onChoose(value) }')

        self.assertIn('selectAfterDismissal.contains($0)', dismiss)
        self.assertLess(immediate, finish)
        self.assertLess(removal, closed)
        self.assertLess(closed, deferred)
        self.assertIn('completion: { _ in finish() }', dismiss)
        self.assertIn('else { finish() }', dismiss)
