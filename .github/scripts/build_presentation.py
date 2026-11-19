#!/usr/bin/env python3
"""Export a PowerPoint deck and build its LaTeX PDF wrapper."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def build(deck, output):
    wrapper = output.with_suffix(".tex")
    soffice = os.environ.get("SOFFICE") or shutil.which("soffice")
    if not soffice:
        sys.exit("Install LibreOffice Impress or set SOFFICE to its executable.")

    with tempfile.TemporaryDirectory(prefix="fpvr-slides-") as temp_dir:
        work = Path(temp_dir).resolve()
        subprocess.run(
            [
                soffice,
                f"-env:UserInstallation={(work / 'lo-profile').as_uri()}",
                "--headless",
                "--convert-to",
                "pdf:impress_pdf_Export",
                "--outdir",
                str(work),
                str(deck),
            ],
            check=True,
        )
        exported = work / deck.with_suffix(".pdf").name
        if not exported.is_file() or exported.stat().st_size == 0:
            sys.exit(f"LibreOffice did not export a PDF for {deck.name}.")
        exported.rename(work / "design-thinking-slides.pdf")

        # The empty TEXINPUTS component keeps the normal TeX search path.
        env = os.environ.copy()
        env["TEXINPUTS"] = str(work) + os.pathsep + env.get("TEXINPUTS", "")
        subprocess.run(
            [
                "pdflatex",
                "-interaction=nonstopmode",
                "-halt-on-error",
                "-recorder",
                f"-output-directory={work}",
                wrapper.name,
            ],
            cwd=wrapper.parent,
            env=env,
            check=True,
        )

        # The recorder sees the temporary PDF. Record its PPTX source too.
        recorder = work / wrapper.with_suffix(".fls").name
        with recorder.open("a", encoding="utf-8") as handle:
            handle.write(f"INPUT {deck}\n")
        shutil.move(recorder, output.with_suffix(".fls"))
        shutil.move(work / output.name, output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("deck", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.deck.resolve(), args.output.resolve())
