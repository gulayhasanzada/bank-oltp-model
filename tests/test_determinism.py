import hashlib
import unittest

from bankmodel.cli import build


def _digest(files: dict[str, str]) -> dict[str, str]:
    return {path: hashlib.sha256(content.encode("utf-8")).hexdigest() for path, content in files.items()}


class DeterminismTest(unittest.TestCase):
    def test_two_builds_are_identical(self):
        first, second = build(), build()
        self.assertEqual(list(first), list(second))
        self.assertEqual(_digest(first), _digest(second))

    def test_output_is_lf_and_newline_terminated(self):
        for path, content in build().items():
            with self.subTest(path=path):
                self.assertNotIn("\r", content)
                self.assertTrue(content.endswith("\n"))


if __name__ == "__main__":
    unittest.main()
