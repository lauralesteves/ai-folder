# AI Folder

A portable `.ai` folder that lives inside any project to provide AI-assisted workflows — code reviews, ticket management, analysis, and more — powered by Claude Code.

## Setup

### 1. Clone into your project

From the root of your project repository:

```bash
git clone git@github.com:lauralesteves/ai-folder.git '.ai'
```

### 2. Initialize

```bash
cd .ai
make init
```

This will:
- Verify prerequisites (GitHub CLI, Claude CLI, shell)
- Confirm the folder is named `.ai` inside a git project
- Add `.ai` to your global gitignore so it's never committed to the parent repo
- Install the `gpatch` shell function
- Copy `CLAUDE.md` and agents to the parent project's `.claude/` folder
- Install the ClickUp MCP server for Claude Code

## Agents

Agents are specialized Claude Code prompts that handle complex, multi-step workflows autonomously. They are defined in `.resources/agents/` and copied to your project's `.claude/agents/` during `make init`.

### ticket-start

Initializes a standardized workspace structure for a ticket, giving you a consistent starting point before development begins.

**Usage** — provide one of the following as input:

| Format | Example |
|---|---|
| ClickUp URL | `I'm starting work on https://app.clickup.com/t/1274576/ABC-123` |
| ClickUp ticket ID | `Starting work on ABC-123` |
| GitHub issue URL | `Let's get started on https://github.com/org/repo/issues/123` |
| GitHub issue number | `Starting work on #123` |

**What it creates:**

```
.ai/tickets/[TICKET-ID]/
  designs/                  # empty, ready for design assets
  PR.md                     # pull request template with ticket reference
  TICKET.md                 # ticket details (fetched or ready to paste)
  IMPLEMENTATION_PLAN.md    # ready for implementation plan
```

**How it resolves ticket content:**
- For ClickUp tickets: checks `.ai/tickets/` first, then fetches via ClickUp MCP if not found
- For GitHub issues: checks `.ai/tickets/` first, then fetches via `gh issue view` if not found
- If neither source has content, creates a minimal placeholder and warns you to paste details manually

---

### code-review

Performs a thorough, multi-perspective code review (developer, tech lead, architect) of a remote branch without touching your working tree.

**Usage** — provide one of the following as input:

| Format | Example | Description |
|---|---|---|
| Branch name | `Review feature/add-logging` | Reviews the remote branch directly |
| GitHub issue | `Review #42` | Looks up the issue, finds its branch, and reviews |
| ClickUp ticket | `Review FL-590` | Looks up the ticket, finds its branch, and reviews |

**How it works:**
1. Resolves the input to a remote branch (fetches ticket context when applicable)
2. Creates an isolated git worktree — your current branch is untouched
3. Generates a diff and analyzes changes from three perspectives
4. Checks for existing PR comments to avoid duplicate findings
5. Writes a `REVIEW-X.md` file and cleans up the worktree

**Where reviews are written:**
- If a GitHub issue or ClickUp ticket was found in `.ai/tickets/`, the review is written to that ticket's folder (e.g., `.ai/tickets/FL-590/REVIEW-1.md`)
- Otherwise, reviews go to `.ai/reviews/<branch-name>/REVIEW-1.md`

Subsequent reviews of the same branch increment the number (`REVIEW-2.md`, `REVIEW-3.md`, etc.).

---

### create-pr

Generates comprehensive pull request documentation from a ticket's patch, commits, and ticket details.

**Usage** — provide one of the following as input:

| Format | Example |
|---|---|
| ClickUp ticket ID | `Create PR for ABC-123` |
| GitHub issue number | `Create PR for #123` |
| Plain number | `Create PR for 123` |

**How it works:**
1. Validates that `.ai/tickets/[TICKET-ID]/` exists — stops if missing
2. Runs `gpatch` to generate a `.patch` file with the branch changes
3. Gathers context from the patch, git commit history, and `TICKET.md`
4. Writes a complete `PR.md` in the ticket folder, filling all sections of the existing template or creating one tailored to the project's tech stack
