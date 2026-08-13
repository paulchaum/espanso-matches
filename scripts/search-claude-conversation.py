#!/usr/bin/env python3
"""Search a substring across every Claude Code conversation and export the matches."""

import json
import sys
from datetime import datetime
from pathlib import Path
import tempfile

# ── ANSI colours ──────────────────────────────────────────────────────────────
RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
# Foreground
CYAN = "\033[36m"
YELLOW = "\033[33m"
GREEN = "\033[32m"
BLUE = "\033[34m"
MAGENTA = "\033[35m"
WHITE = "\033[97m"
RED = "\033[31m"
# Background
BG_BLUE = "\033[44m"
BG_CYAN = "\033[46m"


def c(color: str, text: str) -> str:
    return f"{color}{text}{RESET}"


def hr(char: str = "─", width: int = 72) -> str:
    return c(DIM, char * width)


def header(title: str) -> None:
    print()
    print(c(BOLD + CYAN, f"  ╔══  {title}  ══╗"))
    print()


# ── Projects ──────────────────────────────────────────────────────────────────

PROJECTS_ROOT = Path.home() / ".claude" / "projects"


def list_projects() -> list[Path]:
    if not PROJECTS_ROOT.exists():
        return []
    return sorted(p for p in PROJECTS_ROOT.iterdir() if p.is_dir())


# ── Conversation metadata ──────────────────────────────────────────────────────


def read_conversation_meta(path: Path) -> dict:
    """Return {title, timestamp, uuid} for a JSONL file (fast scan)."""
    title: str = ""
    timestamp: str = ""
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue
        t = obj.get("type", "")
        # Last ai-title wins
        if t == "ai-title":
            title = obj.get("aiTitle", "")
        # First user message timestamp
        if t == "user" and not timestamp:
            timestamp = obj.get("timestamp", "")
    return {
        "title": title or "(untitled)",
        "timestamp": timestamp,
        "uuid": path.stem,
        "path": path,
    }


def fmt_timestamp(ts: str) -> str:
    if not ts:
        return c(DIM, "unknown date")
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        local = dt.astimezone()
        return c(DIM, local.strftime("%Y-%m-%d %H:%M"))
    except ValueError:
        return c(DIM, ts[:16])


# ── Markdown export ────────────────────────────────────────────────────────────


def extract_user_text(content) -> str:
    # Content may be a plain string or a list of blocks.
    if isinstance(content, str):
        return "" if content.startswith("<ide_") else content.strip()
    parts = []
    for block in content:
        if not isinstance(block, dict) or block.get("type") != "text":
            continue
        text = block.get("text", "")
        if text.startswith("<ide_"):
            continue
        parts.append(text)
    return "\n\n".join(parts).strip()


def extract_assistant_text(content) -> str:
    # Content may be a plain string or a list of blocks.
    if isinstance(content, str):
        return content.strip()
    parts = [
        b.get("text", "")
        for b in content
        if isinstance(b, dict) and b.get("type") == "text"
    ]
    return "\n\n".join(parts).strip()


def jsonl_to_markdown(path: Path, meta: dict) -> str:
    sections: list[str] = []

    title = meta.get("title", "(untitled)")
    sections.append(f"# {title}\n\n*Exported from Claude Code · {meta['uuid']}*\n")

    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get("type")

        if msg_type == "user":
            content = obj.get("message", {}).get("content", [])
            text = extract_user_text(content)
            if text:
                sections.append(f"## User\n\n{text}\n")

        elif msg_type == "assistant":
            content = obj.get("message", {}).get("content", [])
            text = extract_assistant_text(content)
            if text:
                sections.append(f"## Assistant\n\n{text}\n")

    return "\n---\n\n".join(sections)


# ── Search ─────────────────────────────────────────────────────────────────────


def count_matches(path: Path, needle: str) -> int:
    """Count case-insensitive occurrences of needle in the raw file text."""
    text = path.read_text(encoding="utf-8", errors="replace")
    return text.lower().count(needle.lower())


def search_all(needle: str) -> list[dict]:
    """Scan every conversation in every project; return matching metas."""
    results: list[dict] = []
    for project in list_projects():
        for jsonl in sorted(project.glob("*.jsonl")):
            hits = count_matches(jsonl, needle)
            if hits:
                meta = read_conversation_meta(jsonl)
                meta["project"] = project.name
                meta["hits"] = hits
                results.append(meta)
    # Newest first
    results.sort(key=lambda m: m["timestamp"], reverse=True)
    return results


# ── Interactive prompts ────────────────────────────────────────────────────────


def ask_needle() -> str | None:
    print()
    try:
        raw = input(c(BOLD + GREEN, "  Search substring › ")).strip()
    except (EOFError, KeyboardInterrupt):
        return None
    return raw or None


def ask_output_dir(default: Path) -> Path | None:
    """Ask which directory to save every match into, blank for default."""
    print()
    print(f"  {c(DIM, 'Output directory')}  [{c(CYAN, str(default))}]  {c(DIM, '(Ctrl+C to cancel)')}")
    try:
        raw = input(c(BOLD + GREEN, "  Save all to › ")).strip()
    except (EOFError, KeyboardInterrupt):
        return None
    return Path(raw).expanduser() if raw else default


# ── Main flow ──────────────────────────────────────────────────────────────────


def main() -> None:
    print()
    print(
        c(BOLD + BG_CYAN + " " * 4, "")
        + c(BOLD + CYAN, "  Claude Code conversation search  ")
        + c(BG_CYAN, "    ")
    )

    # ── Step 1: substring ──────────────────────────────────────────────────
    header("Search all conversations")
    needle = ask_needle()
    if not needle:
        print(c(DIM, "\n  Nothing to search.\n"))
        sys.exit(0)

    # ── Step 2: scan every project / conversation ──────────────────────────
    print()
    print(c(DIM, "  Searching…"), end="\r")
    results = search_all(needle)
    print(" " * 20, end="\r")  # clear "Searching…"

    if not results:
        print(c(YELLOW, f"\n  No matches for {c(BOLD, needle)}.\n"))
        sys.exit(0)

    # ── Step 3: show where it was found ────────────────────────────────────
    header(f"{len(results)} match(es) for  {c(YELLOW, needle)}")
    for i, m in enumerate(results, 1):
        print(
            f"  {c(YELLOW + BOLD, str(i).rjust(2))}  "
            f"{fmt_timestamp(m['timestamp'])}  "
            f"{c(MAGENTA, m['project'])}"
        )
        print(
            f"      {c(WHITE + BOLD, m['title'])}  "
            f"{c(DIM, f'({m['hits']} hit' + ('s' if m['hits'] != 1 else '') + ')')}"
        )
    print()
    print(hr())

    # ── Step 4: save every result ──────────────────────────────────────────
    out_dir = ask_output_dir(Path(tempfile.gettempdir()))
    if out_dir is None:
        print(c(DIM, "\n  Cancelled.\n"))
        sys.exit(0)
    out_dir.mkdir(parents=True, exist_ok=True)

    print()
    print(c(DIM, "  Converting…"), end="\r")
    for m in results:
        safe_title = m["title"][:60].replace("/", "-").replace(" ", "_")
        out_path = out_dir / f"{m['project']}_{safe_title}_{m['uuid'][:8]}.md"
        md = jsonl_to_markdown(m["path"], m)
        out_path.write_text(md, encoding="utf-8")
        print(c(GREEN + BOLD, "  ✓ ") + c(CYAN, str(out_path)) + " " * 4)

    print()
    print(c(GREEN + BOLD, f"  Saved {len(results)} file(s) to ") + c(CYAN, str(out_dir)))
    print()
    print(hr())
    print(c(DIM, "\n  Bye!\n"))


if __name__ == "__main__":
    main()
