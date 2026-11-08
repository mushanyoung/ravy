"""Validate local Markdown navigation, without fetching external links."""

import re
from pathlib import Path
from urllib.parse import unquote

from quality import ROOT, files


def broken_links(path: Path) -> list[str]:
    links = re.findall(r"\]\(([^\s)]+)(?:\s+[^)]*)?\)", path.read_text())
    return [
        link
        for link in links
        if ":" not in link
        and not link.startswith("#")
        and not (path.parent / unquote(link.split("#", 1)[0])).exists()
    ]


def main() -> None:
    errors = [
        f"{path}: broken link {link}"
        for path in files()
        if path.suffix == ".md" and not str(path).startswith("docs/archive/")
        for link in broken_links(ROOT / path)
    ]
    if errors:
        raise SystemExit("\n".join(errors))
    print("Documentation navigation: PASS")


if __name__ == "__main__":
    main()
