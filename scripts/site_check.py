#!/usr/bin/env python3
"""Offline site gate and byte-for-byte static build; Python 3.11+, stdlib only.

Run: python3 scripts/site_check.py [--output NEW_DIRECTORY]
No dependency on the Rust/foundation checks. No requests or external tools.
"""

import argparse
from html.parser import HTMLParser
from pathlib import Path
import re
import shutil
import tempfile
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
SOURCE = "https://github.com/suhaasbadada/threadmark"
CSP = "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"


def require(condition, message):
    if not condition:
        raise ValueError(message)


class Document(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.elements = []
        self.ids = set()
        self.stack = []
        self.text = []

    def handle_decl(self, decl):
        require(decl.lower() == "doctype html", "Expected HTML5 doctype")

    def handle_starttag(self, tag, pairs):
        attrs = dict(pairs)
        require(len(attrs) == len(pairs), "Duplicate attribute")
        require(tag not in {"script", "iframe", "object", "embed", "form", "base", "svg"},
                f"Active/embedded content forbidden: {tag}")
        require(not any(k.startswith("on") for k in attrs), "Inline event handler")
        require(not any(k in attrs for k in ("src", "srcset", "ping", "action")),
                "Unexpected network resource or submission")
        require(attrs.get("tabindex", "0") in {"0", "-1"}, "Positive tabindex")
        if "id" in attrs:
            require(attrs["id"] not in self.ids, "Duplicate ID")
            self.ids.add(attrs["id"])
        self.elements.append((tag, attrs))
        if tag not in {"meta", "link", "br", "hr", "img", "input", "wbr"}:
            self.stack.append(tag)

    def handle_endtag(self, tag):
        require(self.stack and self.stack.pop() == tag, f"Unbalanced HTML: {tag}")

    def handle_data(self, text):
        self.text.append(text)


def check_html(text, directory):
    require(text.startswith("<!doctype html>"), "Missing doctype")
    doc = Document()
    doc.feed(text)
    doc.close()
    require(not doc.stack, "Unclosed HTML")
    elements = doc.elements
    select = lambda tag: [attrs for name, attrs in elements if name == tag]
    require(select("html") == [{"lang": "en"}], "Missing language")
    for tag in ("title", "h1", "main", "header", "footer"):
        require(len(select(tag)) == 1, f"Expected one {tag}")
    require(select("main")[0] == {"id": "main", "tabindex": "-1"}, "Skip target")
    require(select("a")[0].get("href") == "#main", "Skip link must come first")
    require(any(a.get("name") == "viewport" for a in select("meta")), "Viewport")
    require(any(a.get("http-equiv") == "Content-Security-Policy" and
                a.get("content") == CSP for a in select("meta")), "Restrictive CSP")
    previous = 0
    for tag, attrs in elements:
        if re.fullmatch(r"h[1-6]", tag):
            level = int(tag[1])
            require(level <= previous + 1, "Skipped heading level")
            previous = level
        if "aria-labelledby" in attrs:
            require(all(i in doc.ids for i in attrs["aria-labelledby"].split()),
                    "Missing accessible label target")
        if tag == "section":
            require("aria-labelledby" in attrs, "Unlabeled section")
        if tag not in {"a", "link"}:
            continue
        target = attrs.get("href", "")
        require(target, "Empty link")
        url = urlsplit(target)
        if url.scheme or url.netloc:
            require(target == SOURCE and tag == "a", "Unapproved external URL")
        else:
            path = (directory / unquote(url.path)).resolve()
            require(path.is_relative_to(directory.resolve()), "Link escapes site")
            require(path.exists(), "Broken local link")
            require(not url.fragment or url.fragment in doc.ids, "Broken fragment")
    require(len(select("a")) == 2, "Expected skip link and one source CTA")
    require(not select("link"), "No external styles or fonts")
    css = re.search(r"<style>(.*?)</style>", text, re.S).group(1)
    require(not re.search(r"@import|url\s*\(|@font-face|animation\s*:",
                          css.replace("animation: none !important", ""), re.I),
            "External CSS resource or motion")
    for rule in ("prefers-color-scheme: dark", "prefers-reduced-motion: reduce",
                 ":focus-visible", "max-width: 650px"):
        require(rule in css, f"Missing accessibility rule: {rule}")
    visible = " ".join(doc.text)
    for phrase in ("Early development", "No released app", "certified host integration",
                   "permissions", "SQLite", "mem-z", "Graphify", "explicitly authorized inference"):
        require(phrase in visible, f"Missing product boundary: {phrase}")


def check_workflow():
    # Narrow structural contract for this one reviewed workflow, not a YAML parser.
    text = (ROOT / ".github/workflows/pages.yml").read_text()
    require(not any(s in text for s in ("pull_request_target", "workflow_dispatch",
                                      "configure-pages", "secrets.", "write-all")),
            "Unsafe workflow trigger, setup, or credential use")
    build, deploy = text.split("  deploy:\n")
    require("permissions:\n  contents: read\n" in build, "Read-only build")
    require("branches: [main]" in build and "  pull_request:\n" in build, "Triggers")
    require("persist-credentials: false" in build, "Checkout credential persistence")
    require("scripts/site_check.py --output _site" in build, "Missing site gate")
    guard = "github.event_name == 'push' && github.ref == 'refs/heads/main'"
    require(f"    if: {guard}" in deploy and f"        if: {guard}" in build,
            "PR must not upload or deploy Pages")
    require(build.index("scripts/site_check.py") < build.index("uses: actions/upload-pages"),
            "Upload before checks")
    require("Require owner merge of this exact main revision" in build and
            "pr.get('merge_commit_sha') == head" in build and
            "pr.get('merged_by')" in build and
            build.index("Pages blocked:") < build.index("uses: actions/upload-pages"),
            "Missing exact owner-merge gate before upload")
    require("needs: build" in deploy and "name: github-pages" in deploy, "Deploy gate")
    require("pages: write" in deploy and "id-token: write" in deploy and
            "pages: write" not in build and "id-token: write" not in build,
            "Deployment permissions must be isolated")
    uses = re.findall(r"uses: ([^\s]+)", text)
    require(len(uses) == 3 and all(re.fullmatch(r"actions/[a-z-]+@[a-f0-9]{40}", u)
                                  for u in uses), "Official SHA-pinned actions only")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Create a NEW artifact directory")
    args = parser.parse_args()
    site = ROOT / "site"
    files = sorted(p.relative_to(site).as_posix() for p in site.rglob("*") if p.is_file())
    require(files == ["index.html"] and not any(p.is_symlink() for p in site.rglob("*")),
            "Site must contain only the reviewed static HTML; no symlinks")
    require((site / "index.html").stat().st_size < 32_000, "Site exceeds size budget")
    html = (site / "index.html").read_text(encoding="utf-8")
    check_html(html, site)
    check_workflow()
    # Guard self-tests: each deliberately broken fixture must fail, without network.
    for broken in (html.replace('href="#main"', 'href="#missing"'),
                   html.replace("<body>", '<body onload="alert(1)">'),
                   html.replace(SOURCE, "https://example.invalid"),
                   html.replace("<h1>", "<h4>").replace("</h1>", "</h4>")):
        try:
            check_html(broken, site)
        except ValueError:
            continue
        raise ValueError("Negative guard fixture unexpectedly passed")
    with tempfile.TemporaryDirectory(prefix="threadmark-site-") as temp:
        built = Path(temp) / "site"
        shutil.copytree(site, built)
        require((built / "index.html").read_bytes() == (site / "index.html").read_bytes(),
                "Build changed source bytes")
        check_html((built / "index.html").read_text(), built)
        if args.output:
            # Refuse existing destinations, including symlinks; never clean user data.
            require(not args.output.exists() and not args.output.is_symlink(),
                    "Output already exists; choose a new directory")
            shutil.copytree(built, args.output)
    print("PASS: static build, local links, semantic/security guards, workflow contract; "
          "4 negative fixtures rejected. No network used.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        raise SystemExit(f"FAIL: {error}") from error
