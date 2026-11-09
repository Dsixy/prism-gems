"""Compatibility entry point; rebuild the complete current cut library."""
from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).resolve().with_name("build_cuts.py")), run_name="__main__")
