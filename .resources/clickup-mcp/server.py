"""ClickUp MCP Server for Claude Code."""

import os
import re
from datetime import datetime

import httpx
from mcp.server.fastmcp import FastMCP

CLICKUP_API_BASE = "https://api.clickup.com/api/v2"

mcp = FastMCP("clickup")


def _get_token() -> str:
    token = os.environ.get("CLICKUP_API_TOKEN", "")
    if not token:
        raise ValueError("CLICKUP_API_TOKEN environment variable is not set")
    return token


def _headers() -> dict:
    return {
        "Authorization": _get_token(),
        "Content-Type": "application/json",
    }


def _extract_task_id(task_id_or_url: str) -> str:
    """Extract task ID from a ClickUp URL or return as-is."""
    match = re.search(r"/t/(?:\d+/)?([A-Za-z0-9-]+)$", task_id_or_url)
    if match:
        return match.group(1)
    return task_id_or_url.strip()


async def _resolve_custom_id_params(task_id: str) -> dict:
    """If task_id looks like a custom ID (e.g. FL-690), resolve team_id."""
    if not re.match(r"^[A-Za-z]+-\d+$", task_id):
        return {}
    params = {"custom_task_ids": "true"}
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{CLICKUP_API_BASE}/team", headers=_headers())
        resp.raise_for_status()
        teams = resp.json().get("teams", [])
        if teams:
            params["team_id"] = teams[0]["id"]
    return params


def _task_to_markdown(task: dict) -> str:
    """Convert a ClickUp task dict to Markdown."""
    lines = [f"# {task.get('name', 'Untitled')}", ""]

    if task.get("custom_id"):
        lines.append(f"**ID:** {task['custom_id']}")
    lines.append(f"**Task ID:** {task.get('id', 'N/A')}")

    status = task.get("status", {})
    if status:
        lines.append(f"**Status:** {status.get('status', 'N/A')}")

    if task.get("priority"):
        lines.append(f"**Priority:** {task['priority'].get('priority', 'N/A')}")

    assignees = task.get("assignees", [])
    if assignees:
        names = ", ".join(
            a.get("username", a.get("email", "unknown")) for a in assignees
        )
        lines.append(f"**Assignees:** {names}")

    if task.get("due_date"):
        due = datetime.fromtimestamp(int(task["due_date"]) / 1000).strftime("%Y-%m-%d")
        lines.append(f"**Due Date:** {due}")

    tags = task.get("tags", [])
    if tags:
        tag_names = ", ".join(t.get("name", "") for t in tags)
        lines.append(f"**Tags:** {tag_names}")

    if task.get("url"):
        lines.append(f"**URL:** {task['url']}")

    lines.append("")

    description = task.get("description") or task.get("text_content") or ""
    if description:
        lines.extend(["## Description", "", description, ""])

    return "\n".join(lines)


@mcp.tool()
async def get_task(task_id_or_url: str) -> str:
    """Fetch a ClickUp task by ID or URL and return it as Markdown.

    Args:
        task_id_or_url: A ClickUp task ID (e.g. '86abc123') or URL
                        (e.g. 'https://app.clickup.com/t/1274576/FL-690')
    """
    task_id = _extract_task_id(task_id_or_url)
    params = await _resolve_custom_id_params(task_id)

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{CLICKUP_API_BASE}/task/{task_id}",
            headers=_headers(),
            params=params,
        )
        resp.raise_for_status()
        return _task_to_markdown(resp.json())


@mcp.tool()
async def get_task_comments(task_id_or_url: str) -> str:
    """Fetch comments for a ClickUp task and return them as Markdown.

    Args:
        task_id_or_url: A ClickUp task ID or URL
    """
    task_id = _extract_task_id(task_id_or_url)
    params = await _resolve_custom_id_params(task_id)

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{CLICKUP_API_BASE}/task/{task_id}/comment",
            headers=_headers(),
            params=params,
        )
        resp.raise_for_status()
        comments = resp.json().get("comments", [])

    if not comments:
        return "No comments found for this task."

    lines = ["# Task Comments", ""]
    for c in comments:
        user = c.get("user", {}).get("username", "Unknown")
        date = datetime.fromtimestamp(int(c.get("date", 0)) / 1000).strftime(
            "%Y-%m-%d %H:%M"
        )
        text = c.get("comment_text", "")
        lines.extend([f"### {user} — {date}", "", text, "", "---", ""])

    return "\n".join(lines)


@mcp.tool()
async def save_task_as_markdown(
    task_id_or_url: str, output_dir: str = "tickets"
) -> str:
    """Fetch a ClickUp task and save it as a Markdown file.

    Args:
        task_id_or_url: A ClickUp task ID or URL
        output_dir: Directory to save the markdown file (default: 'tickets')
    """
    task_id = _extract_task_id(task_id_or_url)
    params = await _resolve_custom_id_params(task_id)

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{CLICKUP_API_BASE}/task/{task_id}",
            headers=_headers(),
            params=params,
        )
        resp.raise_for_status()
        task = resp.json()

    md_content = _task_to_markdown(task)

    os.makedirs(output_dir, exist_ok=True)
    custom_id = task.get("custom_id", task.get("id", task_id))
    filepath = os.path.join(output_dir, f"{custom_id}.md")

    with open(filepath, "w") as f:
        f.write(md_content)

    return f"Task saved to {filepath}"


if __name__ == "__main__":
    mcp.run()
