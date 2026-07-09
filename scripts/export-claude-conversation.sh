#!/usr/bin/env python3
"""Interactive shell to browse and export Claude Code conversations to Markdown."""

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


def extract_user_text(content: list) -> str:
    parts = []
    for block in content:
        if block.get("type") != "text":
            continue
        text = block.get("text", "")
        if text.startswith("<ide_"):
            continue
        parts.append(text)
    return "\n\n".join(parts).strip()


def extract_assistant_text(content: list) -> str:
    parts = [b.get("text", "") for b in content if b.get("type") == "text"]
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


# ── Interactive prompts ────────────────────────────────────────────────────────


def prompt_choice(items: list[str], prompt: str = "Select") -> int | None:
    """Show a numbered list and return the 0-based index, or None on quit."""
    for i, item in enumerate(items, 1):
        print(f"  {c(YELLOW + BOLD, str(i).rjust(2))}  {item}")
    print()
    print(f"  {c(DIM, 'q')} · quit    {c(DIM, '0')} · go back")
    print()
    while True:
        try:
            raw = input(c(BOLD + GREEN, f"  {prompt} › ")).strip()
        except (EOFError, KeyboardInterrupt):
            return None
        if raw.lower() in ("q", "quit", "exit"):
            return None
        if raw == "0":
            return -1  # sentinel: go back
        try:
            n = int(raw)
            if 1 <= n <= len(items):
                return n - 1
        except ValueError:
            pass
        print(c(RED, f"  Please enter a number 1–{len(items)}."))


def ask_output_path(default: Path) -> Path | None:
    """Ask where to save, accepting blank for default."""
    print()
    print(f"  {c(DIM, 'Output file')}  [{c(CYAN, str(default))}]")
    try:
        raw = input(c(BOLD + GREEN, "  Save to › ")).strip()
    except (EOFError, KeyboardInterrupt):
        return None
    return Path(raw) if raw else default


# ── Main flow ──────────────────────────────────────────────────────────────────


def main() -> None:
    print()
    print(
        c(BOLD + BG_CYAN + " " * 4, "")
        + c(BOLD + CYAN, "  Claude Code → Markdown exporter  ")
        + c(BG_CYAN, "    ")
    )

    while True:
        # ── Step 1: choose project ─────────────────────────────────────────
        projects = list_projects()
        if not projects:
            print(c(RED, f"\n  No projects found in {PROJECTS_ROOT}"))
            sys.exit(1)

        header("Select a project")
        labels = [f"{c(WHITE + BOLD, p.name)}" for p in projects]
        idx = prompt_choice(labels, "Project")
        if idx is None:
            print(c(DIM, "\n  Bye!\n"))
            sys.exit(0)
        if idx == -1:
            continue

        project = projects[idx]

        while True:
            # ── Step 2: list conversations ─────────────────────────────────
            jsonl_files = sorted(project.glob("*.jsonl"))
            if not jsonl_files:
                print(c(RED, f"\n  No conversations found in {project.name}\n"))
                break

            header(f"Conversations in  {c(CYAN, project.name)}")
            print(c(DIM, "  Loading…"), end="\r")

            metas = [read_conversation_meta(f) for f in jsonl_files]
            # Sort oldest first
            metas.sort(key=lambda m: m["timestamp"])

            labels = []
            for m in metas:
                labels.append(
                    f"{fmt_timestamp(m['timestamp'])} {c(WHITE + BOLD, m['title'])}"
                )

            print(" " * 20, end="\r")  # clear "Loading…"
            idx2 = prompt_choice(labels, "Conversation")
            if idx2 is None:
                print(c(DIM, "\n  Bye!\n"))
                sys.exit(0)
            if idx2 == -1:
                break  # back to project selection

            meta = metas[idx2]

            # ── Step 3: choose output path ─────────────────────────────────
            safe_title = meta["title"][:60].replace("/", "-").replace(" ", "_")
            default_out = Path(tempfile.gettempdir()) / f"{safe_title}.md"
            out_path = ask_output_path(default_out)
            if out_path is None:
                print(c(DIM, "\n  Bye!\n"))
                sys.exit(0)

            # ── Step 4: export ─────────────────────────────────────────────
            print()
            print(c(DIM, "  Converting…"), end="\r")
            md = jsonl_to_markdown(meta["path"], meta)
            out_path.write_text(md, encoding="utf-8")
            print(c(GREEN + BOLD, "  ✓ Saved  ") + c(CYAN, str(out_path)) + " " * 10)
            print()
            print(hr())
            print(c(DIM, "\n  Bye!\n"))
            sys.exit(0)


if __name__ == "__main__":
    main()
