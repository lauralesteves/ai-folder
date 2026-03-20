SHELL := /bin/bash

FOLDER_NAME := $(notdir $(CURDIR))
PARENT_DIR  := $(abspath $(CURDIR)/..)

GREEN  := \033[0;32m
RED    := \033[0;31m
YELLOW := \033[0;33m
NC     := \033[0m
CHECK  := \xE2\x9C\x94
CROSS  := \xE2\x9C\x98

.PHONY: check check-github check-claude check-terminal check-environment \
        ignore-ai-folder add-gpatch-script prepare-claude install-clickup-mcp init

# ===========================================================================
#  Individual checks
# ===========================================================================

check-github: ## Check if GitHub CLI is installed and user is authenticated
	@echo ""
	@echo "--- GitHub CLI ---"
	@if ! command -v gh >/dev/null 2>&1; then \
		printf "  $(RED)$(CROSS) gh CLI not installed$(NC)\n"; \
		echo "    Install with: brew install gh"; \
		exit 1; \
	fi
	@printf "  $(GREEN)$(CHECK) gh installed: %s$(NC)\n" "$$(gh --version | head -1)"
	@if ! gh auth token >/dev/null 2>&1; then \
		printf "  $(RED)$(CROSS) Not logged in to GitHub$(NC)\n"; \
		echo "    Run: gh auth login"; \
		exit 1; \
	fi
	@printf "  $(GREEN)$(CHECK) Logged in as: %s$(NC)\n" "$$(gh api user -q '.login')"

check-claude: ## Check if Claude CLI is installed
	@echo ""
	@echo "--- Claude CLI ---"
	@if command -v claude >/dev/null 2>&1; then \
		printf "  $(GREEN)$(CHECK) claude installed$(NC)\n"; \
	else \
		printf "  $(RED)$(CROSS) claude CLI not found$(NC)\n"; \
		echo "    Install: https://docs.anthropic.com/en/docs/claude-code"; \
		exit 1; \
	fi

check-terminal: ## Check if zsh or bash is the active shell
	@echo ""
	@echo "--- Terminal Shell ---"
	@if [ -n "$$ZSH_VERSION" ] || echo "$$SHELL" | grep -q zsh; then \
		printf "  $(GREEN)$(CHECK) zsh detected$(NC)\n"; \
	elif [ -n "$$BASH_VERSION" ] || echo "$$SHELL" | grep -q bash; then \
		printf "  $(GREEN)$(CHECK) bash detected$(NC)\n"; \
	else \
		printf "  $(YELLOW)! Unknown shell: $$SHELL$(NC)\n"; \
	fi

check-environment: ## Check folder name is .ai and parent has .git
	@echo ""
	@echo "--- Environment ---"
	@if [ "$(FOLDER_NAME)" = ".ai" ]; then \
		printf "  $(GREEN)$(CHECK) Folder is .ai$(NC)\n"; \
	else \
		printf "  $(RED)$(CROSS) Folder is '$(FOLDER_NAME)' — it should be '.ai' inside a project$(NC)\n"; \
		echo "    Rename with: mv $(CURDIR) $(PARENT_DIR)/.ai"; \
		exit 1; \
	fi
	@if [ -d "$(PARENT_DIR)/.git" ]; then \
		printf "  $(GREEN)$(CHECK) Parent project has .git$(NC)\n"; \
	else \
		printf "  $(RED)$(CROSS) No .git found in parent ($(PARENT_DIR))$(NC)\n"; \
		echo "    This .ai folder should live inside a git project"; \
		exit 1; \
	fi

# ===========================================================================
#  Aggregate check
# ===========================================================================

check: ## Run all checks (github, claude, terminal, environment)
	@echo "========================================="
	@echo " Running environment checks"
	@echo "========================================="
	@$(MAKE) --no-print-directory check-github
	@$(MAKE) --no-print-directory check-claude
	@$(MAKE) --no-print-directory check-terminal
	@$(MAKE) --no-print-directory check-environment
	@echo ""
	@echo "========================================="
	@printf " $(GREEN)All checks passed!$(NC)\n"
	@echo "========================================="

# ===========================================================================
#  Setup targets
# ===========================================================================

ignore-ai-folder: ## Ensure .ai is in the global gitignore
	@echo ""
	@echo "--- Global gitignore ---"
	@if [ -f ~/.gitignore ] && grep -qx '.ai' ~/.gitignore 2>/dev/null; then \
		printf "  $(GREEN)$(CHECK) .ai already in ~/.gitignore — skipping$(NC)\n"; \
	elif [ -f ~/.gitignore ]; then \
		echo '.ai' >> ~/.gitignore; \
		printf "  $(GREEN)$(CHECK) Added .ai to ~/.gitignore$(NC)\n"; \
	else \
		echo '.ai' > ~/.gitignore; \
		printf "  $(GREEN)$(CHECK) Created ~/.gitignore with .ai$(NC)\n"; \
	fi
	@if ! git config --global core.excludesFile >/dev/null 2>&1; then \
		git config --global core.excludesFile ~/.gitignore; \
		printf "  $(GREEN)$(CHECK) Set core.excludesFile to ~/.gitignore$(NC)\n"; \
	fi

add-gpatch-script: ## Install gpatch shell function
	@echo ""
	@echo "--- gpatch script ---"
	@ZSH_CUSTOM_DIR="$${ZSH_CUSTOM:-$$HOME/.oh-my-zsh/custom}"; \
	if command -v gpatch >/dev/null 2>&1 || type gpatch >/dev/null 2>&1 \
		|| [ -f "$$ZSH_CUSTOM_DIR/gpatch.zsh" ] \
		|| grep -rq 'gpatch' "$$ZSH_CUSTOM_DIR"/*.zsh 2>/dev/null \
		|| grep -q 'gpatch' ~/.zshrc 2>/dev/null \
		|| grep -q 'gpatch' ~/.bashrc 2>/dev/null; then \
		printf "  $(GREEN)$(CHECK) gpatch already available — skipping$(NC)\n"; \
	else \
		if echo "$$SHELL" | grep -q zsh && [ -d "$$ZSH_CUSTOM_DIR" ]; then \
			cp .resources/scripts/gpatch.sh "$$ZSH_CUSTOM_DIR/gpatch.zsh"; \
			printf "  $(GREEN)$(CHECK) Copied to $$ZSH_CUSTOM_DIR/gpatch.zsh$(NC)\n"; \
			echo "    Reload with: source ~/.zshrc"; \
		elif echo "$$SHELL" | grep -q zsh; then \
			echo "" >> ~/.zshrc; \
			echo "# gpatch - generate patch from current branch" >> ~/.zshrc; \
			cat .resources/scripts/gpatch.sh >> ~/.zshrc; \
			printf "  $(GREEN)$(CHECK) Appended to ~/.zshrc$(NC)\n"; \
			echo "    Reload with: source ~/.zshrc"; \
		elif echo "$$SHELL" | grep -q bash; then \
			echo "" >> ~/.bashrc; \
			echo "# gpatch - generate patch from current branch" >> ~/.bashrc; \
			cat .resources/scripts/gpatch.sh >> ~/.bashrc; \
			printf "  $(GREEN)$(CHECK) Appended to ~/.bashrc$(NC)\n"; \
			echo "    Reload with: source ~/.bashrc"; \
		else \
			printf "  $(YELLOW)! Unsupported shell: $$SHELL — manually source .resources/scripts/gpatch.sh$(NC)\n"; \
		fi; \
	fi

prepare-claude: ## Copy CLAUDE.md and agents to parent project's .claude/ folder
	@echo ""
	@echo "--- Prepare .claude folder ---"
	@if [ ! -d "$(PARENT_DIR)/.claude" ]; then \
		mkdir -p "$(PARENT_DIR)/.claude"; \
		printf "  $(GREEN)$(CHECK) Created $(PARENT_DIR)/.claude$(NC)\n"; \
	fi
	@if [ -f ".resources/CLAUDE.md" ]; then \
		cp .resources/CLAUDE.md "$(PARENT_DIR)/.claude/CLAUDE.md"; \
		printf "  $(GREEN)$(CHECK) Copied CLAUDE.md to $(PARENT_DIR)/.claude/CLAUDE.md$(NC)\n"; \
	else \
		printf "  $(YELLOW)! No CLAUDE.md found in .resources$(NC)\n"; \
	fi
	@if [ ! -d "$(PARENT_DIR)/.claude/agents" ]; then \
		mkdir -p "$(PARENT_DIR)/.claude/agents"; \
		printf "  $(GREEN)$(CHECK) Created $(PARENT_DIR)/.claude/agents$(NC)\n"; \
	fi
	@if [ -d ".resources/agents" ] && [ "$$(ls -A .resources/agents 2>/dev/null)" ]; then \
		cp -r .resources/agents/* "$(PARENT_DIR)/.claude/agents/"; \
		printf "  $(GREEN)$(CHECK) Copied agents to $(PARENT_DIR)/.claude/agents$(NC)\n"; \
	else \
		printf "  $(YELLOW)! No agents found in .resources/agents$(NC)\n"; \
	fi
	@if [ -f ".resources/mcp.json" ]; then \
		if [ -f "$(PARENT_DIR)/.claude/mcp.json" ]; then \
			python3 -c " \
import json, sys; \
src = json.load(open('.resources/mcp.json')); \
dst = json.load(open('$(PARENT_DIR)/.claude/mcp.json')); \
dst.setdefault('mcpServers', {}).update(src.get('mcpServers', {})); \
json.dump(dst, open('$(PARENT_DIR)/.claude/mcp.json', 'w'), indent=2); \
print('  done') \
			"; \
			printf "  $(GREEN)$(CHECK) Merged mcp.json into $(PARENT_DIR)/.claude/mcp.json$(NC)\n"; \
		else \
			cp .resources/mcp.json "$(PARENT_DIR)/.claude/mcp.json"; \
			printf "  $(GREEN)$(CHECK) Copied mcp.json to $(PARENT_DIR)/.claude/mcp.json$(NC)\n"; \
		fi; \
	fi
	@if [ -d ".resources/clickup-mcp" ]; then \
		mkdir -p "$(PARENT_DIR)/.claude/clickup-mcp"; \
		cp -r .resources/clickup-mcp/* "$(PARENT_DIR)/.claude/clickup-mcp/"; \
		printf "  $(GREEN)$(CHECK) Copied clickup-mcp to $(PARENT_DIR)/.claude/clickup-mcp$(NC)\n"; \
	fi

install-clickup-mcp: ## Install ClickUp MCP server for Claude Code
	@echo ""
	@echo "--- ClickUp MCP Server ---"
	@if python3 -c "import mcp" 2>/dev/null && python3 -c "import httpx" 2>/dev/null \
		&& [ -n "$$CLICKUP_API_TOKEN" ]; then \
		printf "  $(GREEN)$(CHECK) ClickUp MCP already installed — skipping$(NC)\n"; \
	else \
		echo "  Installing Python dependencies..."; \
		pip3 install -q -r .resources/clickup-mcp/requirements.txt; \
		python3 -c "import mcp; v = getattr(mcp, '__version__', 'unknown'); print('  mcp version:', v)"; \
		if [ -f .resources/mcp.json ]; then \
			printf "  $(GREEN)$(CHECK) .resources/mcp.json found$(NC)\n"; \
		else \
			printf "  $(RED)$(CROSS) .resources/mcp.json not found$(NC)\n"; \
			exit 1; \
		fi; \
		printf "  $(GREEN)$(CHECK) ClickUp MCP installed$(NC)\n"; \
		echo ""; \
		echo "  REQUIRED: Set your ClickUp API token"; \
		echo "    1. Get token from: ClickUp -> Settings -> Apps -> API Token"; \
		echo '    2. Add to shell profile: export CLICKUP_API_TOKEN="pk_YOUR_TOKEN"'; \
		echo "    3. Reload shell and restart Claude Code"; \
		echo ""; \
		echo "  Tools available after restart:"; \
		echo "    - get_task              Fetch a task by ID/URL as Markdown"; \
		echo "    - get_task_comments     Fetch comments for a task"; \
		echo "    - save_task_as_markdown Fetch + save to tickets/"; \
	fi

# ===========================================================================
#  Full initialization
# ===========================================================================

init: ## Full setup: checks, gitignore, gpatch, claude config, clickup MCP
	@echo "========================================="
	@echo " Initializing AI Folder"
	@echo "========================================="
	@$(MAKE) --no-print-directory check
	@$(MAKE) --no-print-directory ignore-ai-folder
	@$(MAKE) --no-print-directory add-gpatch-script
	@$(MAKE) --no-print-directory prepare-claude
	@$(MAKE) --no-print-directory install-clickup-mcp
	@echo ""
	@echo "========================================="
	@printf " $(GREEN)$(CHECK) Initialization complete!$(NC)\n"
	@echo "========================================="
