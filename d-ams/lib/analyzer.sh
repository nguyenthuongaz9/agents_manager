#!/bin/bash
#===============================================================================
# Requirements Analyzer - D-AMS
# Auto-detects team composition, tech stack, and generates .claude/ config
# from project requirements text — no extra API call needed.
#===============================================================================

# Globals set by run_analysis (read by callers)
TEAM_KEYS=""    # space-separated agent keys for active project
STACK_STR=""    # detected tech stack string
CLAUDE_DIR=""   # path to generated .claude/ folder

#-------------------------------------------------------------------------------
# detect_team — keyword-based agent selection
# $1 = requirements text   $2 = project type
# Prints space-separated list of agent keys
#-------------------------------------------------------------------------------
detect_team() {
    local requirements="$1"
    local project_type="${2:-}"
    local req; req=$(echo "$requirements" | tr '[:upper:]' '[:lower:]')

    local -A chosen=()
    chosen[LEADER]=1

    # Backend
    if echo "$req" | grep -qE 'api|server|backend|rest|graphql|endpoint|express|fastapi|django|flask|spring|node\.?js|golang|rust server|php|laravel|rails'; then
        chosen[BACKEND]=1
    fi
    [[ "$project_type" == "web" || "$project_type" == "api" ]] && chosen[BACKEND]=1

    # Frontend
    if echo "$req" | grep -qE '\bui\b|frontend|interface|react|vue|angular|svelte|html|css|dashboard|web app|next\.?js|nuxt|remix|astro|tailwind'; then
        chosen[FRONTEND]=1
    fi
    [[ "$project_type" == "web" ]] && chosen[FRONTEND]=1

    # DBA
    if echo "$req" | grep -qE 'database|sql|postgres|mysql|mongodb|sqlite|redis|cassandra|schema|migration|orm|prisma|drizzle|supabase|table|index|query'; then
        chosen[DBA]=1
    fi

    # Mobile
    if echo "$req" | grep -qE 'mobile|ios|android|react.?native|flutter|swift|kotlin|xamarin|app.?store|play.?store'; then
        chosen[MOBILE]=1
    fi
    [[ "$project_type" == "mobile" ]] && chosen[MOBILE]=1

    # ML / AI
    if echo "$req" | grep -qE 'machine.?learning|\bml\b|model train|neural|predict|classif|nlp|computer.?vision|deep.?learning|pytorch|tensorflow|sklearn|transformers|\bllm\b|embedding|fine.?tun'; then
        chosen[ML]=1
    fi
    [[ "$project_type" == "ai" ]] && chosen[ML]=1

    # Data Science
    if echo "$req" | grep -qE 'data.?analys|pandas|numpy|visualiz|notebook|jupyter|etl|data.?pipeline|warehouse|\bdbt\b|spark|report|chart|graph|statistic'; then
        chosen[DATA]=1
    fi

    # DevOps
    if echo "$req" | grep -qE 'deploy|docker|kubernetes|\bk8s\b|ci.?cd|devops|infrastructure|terraform|helm|nginx|ansible|container|cloud|\baws\b|\bgcp\b|azure|heroku|vercel'; then
        chosen[DEVOPS]=1
    fi

    # Security
    if echo "$req" | grep -qE 'security|auth(entication|orization)?|oauth|jwt|encrypt|pentest|audit|vulnerabilit|ssl|tls|compliance|rbac|2fa|mfa'; then
        chosen[SECURITY]=1
    fi

    # QA always present
    chosen[QA]=1

    # Emit in canonical order so deps work correctly
    local ordered=(LEADER BACKEND FRONTEND DBA MOBILE ML DATA DEVOPS SECURITY QA)
    local result=""
    for k in "${ordered[@]}"; do
        [[ -n "${chosen[$k]:-}" ]] && result+=" $k"
    done
    echo "${result# }"
}

#-------------------------------------------------------------------------------
# detect_stack — keyword-based tech stack detection
# $1 = requirements text   $2 = project type
# Prints space-separated list of technology names
#-------------------------------------------------------------------------------
detect_stack() {
    local req; req=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local -a stack=()

    # Languages (check most specific first)
    echo "$req" | grep -qE '\btypescript\b'        && stack+=(TypeScript)
    # Python — also inferred from common Python libraries
    echo "$req" | grep -qE '\bpython\b|\bpandas\b|\bnumpy\b|\bmatplotlib\b|\bseaborn\b|\bscikit.?learn\b|\bpytorch\b|\btensorflow\b|\bjupyter\b|\bfastapi\b|\bdjango\b|\bflask\b' && stack+=(Python)
    echo "$req" | grep -qE '\bgolang?\b'            && stack+=(Go)
    echo "$req" | grep -qE '\brust\b'               && stack+=(Rust)
    echo "$req" | grep -qE '\bjava\b'               && stack+=(Java)
    echo "$req" | grep -qE '\bswift\b'              && stack+=(Swift)
    echo "$req" | grep -qE '\bkotlin\b'             && stack+=(Kotlin)
    echo "$req" | grep -qE '\bphp\b'                && stack+=(PHP)
    # JS only if TS not already added
    if echo "$req" | grep -qE '\bjavascript\b|\bjs\b' && ! printf '%s\n' "${stack[@]}" | grep -q TypeScript; then
        stack+=(JavaScript)
    fi

    # Frameworks / runtimes
    echo "$req" | grep -qE '\bnext\.?js\b'          && stack+=(Next.js)
    echo "$req" | grep -qE '\breact\b'              && stack+=(React)
    echo "$req" | grep -qE '\bvue\b'                && stack+=(Vue)
    echo "$req" | grep -qE '\bangular\b'            && stack+=(Angular)
    echo "$req" | grep -qE '\bsvelte\b'             && stack+=(Svelte)
    echo "$req" | grep -qE '\btailwind\b'           && stack+=(Tailwind)
    echo "$req" | grep -qE '\bfastapi\b'            && stack+=(FastAPI)
    echo "$req" | grep -qE '\bdjango\b'             && stack+=(Django)
    echo "$req" | grep -qE '\bflask\b'              && stack+=(Flask)
    echo "$req" | grep -qE '\bexpress\b'            && stack+=(Express)
    echo "$req" | grep -qE '\bspring\b'             && stack+=("Spring Boot")
    echo "$req" | grep -qE '\blaravel\b'            && stack+=(Laravel)
    echo "$req" | grep -qE '\bflutter\b'            && stack+=(Flutter)
    echo "$req" | grep -qE '\bpytorch\b'            && stack+=(PyTorch)
    echo "$req" | grep -qE '\btensorflow\b'         && stack+=(TensorFlow)
    echo "$req" | grep -qE '\bpandas\b'             && stack+=(pandas)
    echo "$req" | grep -qE '\bscikit.?learn\b|\bsklearn\b' && stack+=(scikit-learn)
    echo "$req" | grep -qE '\bprisma\b'             && stack+=(Prisma)

    # Databases
    echo "$req" | grep -qE '\bpostgres\b'           && stack+=(PostgreSQL)
    echo "$req" | grep -qE '\bmysql\b'              && stack+=(MySQL)
    echo "$req" | grep -qE '\bmongodb?\b'           && stack+=(MongoDB)
    echo "$req" | grep -qE '\bsqlite\b'             && stack+=(SQLite)
    echo "$req" | grep -qE '\bredis\b'              && stack+=(Redis)
    echo "$req" | grep -qE '\bsupabase\b'           && stack+=(Supabase)

    # Infra
    echo "$req" | grep -qE '\bdocker\b'             && stack+=(Docker)
    echo "$req" | grep -qE '\bkubernetes\b|\bk8s\b' && stack+=(Kubernetes)
    echo "$req" | grep -qE '\bterraform\b'          && stack+=(Terraform)

    echo "${stack[*]}"
}

#-------------------------------------------------------------------------------
# _gen_rules — generate coding rules based on stack + requirements
# $1 = stack string   $2 = project type   $3 = requirements (lowercase)
# Prints one rule per line
#-------------------------------------------------------------------------------
_gen_rules() {
    local stack="$1"
    local ptype="$2"
    local req="$3"
    local -a rules=()

    # Universal
    rules+=("Use Write/Edit/Bash tools to create ACTUAL FILES — never print code blocks in chat")
    rules+=("After completing your role, write checkpoint-ROLENAME.md listing every file created")
    rules+=("Run tests/build via Bash before marking work done — fix all errors")
    rules+=("Follow the ARCHITECTURE.md tech stack decisions — do not introduce new dependencies without justification")

    # TypeScript
    echo "$stack" | grep -qi TypeScript && rules+=(
        "Enable strict mode in tsconfig (\"strict\": true)"
        "No implicit any — all function params and return types must be typed"
    )

    # Python
    echo "$stack" | grep -qi Python && rules+=(
        "Follow PEP 8 style — use ruff or flake8 if available"
        "Add type hints to all function signatures"
        "Pin dependencies in requirements.txt or pyproject.toml"
    )

    # React
    echo "$stack" | grep -qi React && rules+=(
        "Functional components and hooks only — no class components"
        "Keep components small; extract reusable logic into custom hooks"
    )

    # API frameworks
    echo "$stack" | grep -qiE 'FastAPI|Express|Django|Flask|Spring' && rules+=(
        "Validate all request inputs at the API boundary (Pydantic / Zod / Joi)"
        "Return consistent error shape: {error: string, code: number}"
        "Add OpenAPI/Swagger docs to all public endpoints"
    )

    # Database
    echo "$stack" | grep -qiE 'PostgreSQL|MySQL|SQLite|MongoDB' && rules+=(
        "Use migrations for all schema changes — never ALTER TABLE manually"
        "Index foreign keys and frequently filtered columns"
    )

    # Auth detected in requirements
    echo "$req" | grep -qE 'auth|login|password|user account' && rules+=(
        "Hash passwords with bcrypt/argon2 — never store plaintext"
        "Store auth tokens in httpOnly cookies or secure storage — not localStorage"
        "Rate-limit auth endpoints"
    )

    # Docker
    echo "$stack" | grep -qi Docker && rules+=(
        "Use multi-stage Docker builds to minimize image size"
        "Do not run containers as root — use a non-root USER"
    )

    # Web security
    [[ "$ptype" == "web" ]] && rules+=(
        "Sanitize all user inputs — prevent XSS and SQL injection"
        "Set CORS headers explicitly — do not use wildcard in production"
    )

    printf '%s\n' "${rules[@]}"
}

#-------------------------------------------------------------------------------
# _gen_commands — write .claude/commands/ slash-command files
# $1 = commands_dir   $2 = stack string
#-------------------------------------------------------------------------------
_gen_commands() {
    local dir="$1"
    local stack="$2"

    # Always: run-tests, build, status
    cat > "$dir/run-tests.md" <<'EOF'
Run the full test suite and report results.

1. Detect test runner from project files (jest/vitest/pytest/go test/cargo test/etc.)
2. Run all tests via Bash — capture full output
3. Report: passed / failed / skipped counts and coverage if available
4. For each failing test: show error, fix the source file, re-run until green
EOF

    cat > "$dir/build.md" <<'EOF'
Build the project and check for errors.

1. Detect build tool (npm run build / cargo build / go build / make / etc.)
2. Run the build via Bash
3. Fix any compilation or type errors found
4. Report success and list output artifacts
EOF

    cat > "$dir/status.md" <<'EOF'
Show current project state: what is built, what is pending.

1. Run: find . -type f -not -path './.git/*' -not -path './node_modules/*' -not -path './__pycache__/*' | sort
2. List which checkpoint-*.md files exist and read each one
3. Summarise agent progress per role
4. Report what still needs to be done
EOF

    # Frontend devserver
    echo "$stack" | grep -qiE 'React|Vue|Angular|Svelte|Next|Nuxt' && cat > "$dir/dev-server.md" <<'EOF'
Start the frontend development server.

1. Check package.json for the dev script (npm run dev / yarn dev / pnpm dev)
2. Start it via Bash
3. Report the local URL where the app is accessible
EOF

    # Docker
    echo "$stack" | grep -qi Docker && cat > "$dir/docker-up.md" <<'EOF'
Start all Docker services.

1. Check if docker-compose.yml or compose.yaml exists
2. Run: docker compose up --build -d
3. Run: docker compose ps — check all services are healthy
4. Print logs for any unhealthy service
EOF

    # Database
    echo "$stack" | grep -qiE 'PostgreSQL|MySQL|MongoDB|SQLite|Prisma|Supabase' && cat > "$dir/db-migrate.md" <<'EOF'
Run pending database migrations.

1. Detect migration tool (prisma migrate dev / alembic upgrade head / flyway migrate / etc.)
2. Run pending migrations via Bash
3. Report which migrations were applied
4. Show error and suggest fix if migration fails
EOF

    # Python/ML
    echo "$stack" | grep -qiE 'Python|PyTorch|TensorFlow' && cat > "$dir/lint.md" <<'EOF'
Lint and format Python code.

1. Run ruff check . --fix (or flake8 + black if ruff not available) via Bash
2. Run mypy . for type checking
3. Fix all reported issues
4. Report final lint status
EOF
}

#-------------------------------------------------------------------------------
# generate_claude_config — create .claude/ folder in workspace
# $1=workspace  $2=project_name  $3=project_type
# $4=team_keys (space-separated)  $5=stack_str  $6=requirements
# Prints path to created .claude/ dir
#-------------------------------------------------------------------------------
generate_claude_config() {
    local workspace="$1"
    local project_name="$2"
    local project_type="$3"
    local team_keys="$4"
    local stack_str="$5"
    local requirements="$6"

    local claude_dir="$workspace/.claude"
    local commands_dir="$claude_dir/commands"
    mkdir -p "$commands_dir"

    local req_lower; req_lower=$(echo "$requirements" | tr '[:upper:]' '[:lower:]')

    # --- CLAUDE.md ---
    {
        printf '# %s\n\n' "$project_name"
        printf '**Type:** %s' "$project_type"
        [ -n "$stack_str" ] && printf '  |  **Stack:** %s' "$stack_str"
        printf '\n\n'

        printf '## Active team\n\n'
        for key in $team_keys; do
            local name_var="AGENT_${key}_NAME"
            local role_var="AGENT_${key}_ROLE"
            echo "- **${!name_var:-$key}** — ${!role_var:-developer}"
        done
        printf '\n'

        printf '## Rules (all agents must follow)\n\n'
        while IFS= read -r rule; do
            echo "- ${rule}"
        done < <(_gen_rules "$stack_str" "$project_type" "$req_lower")
        printf '\n'

        printf '## File layout\n\n'
        printf 'This directory IS the project root.\n'
        printf 'Always use relative paths: `./src/`, `./tests/`, `./docs/`\n\n'

        printf '## Checkpoint protocol\n\n'
        printf 'Every agent MUST write `checkpoint-ROLENAME.md` when done.\n'
        printf 'List every file created, its purpose, and current status (done/partial/blocked).\n'
    } > "$workspace/CLAUDE.md"

    # --- .claude/settings.json --- pre-approve common tools so agents don't get stuck
    cat > "$claude_dir/settings.json" <<'JSON'
{
  "permissions": {
    "allow": [
      "Bash(ls:*)", "Bash(find:*)", "Bash(cat:*)", "Bash(grep:*)",
      "Bash(mkdir:*)", "Bash(cp:*)", "Bash(mv:*)", "Bash(rm:*)", "Bash(chmod:*)",
      "Bash(git:*)",
      "Bash(npm:*)", "Bash(npx:*)", "Bash(node:*)", "Bash(yarn:*)", "Bash(pnpm:*)",
      "Bash(pip:*)", "Bash(pip3:*)", "Bash(python:*)", "Bash(python3:*)",
      "Bash(poetry:*)", "Bash(uv:*)",
      "Bash(go:*)", "Bash(cargo:*)", "Bash(rustc:*)",
      "Bash(make:*)", "Bash(cmake:*)",
      "Bash(docker:*)", "Bash(docker-compose:*)",
      "Bash(curl:*)", "Bash(wget:*)",
      "Bash(psql:*)", "Bash(mysql:*)", "Bash(mongosh:*)",
      "Bash(ruff:*)", "Bash(black:*)", "Bash(mypy:*)",
      "Bash(jest:*)", "Bash(vitest:*)", "Bash(pytest:*)"
    ],
    "deny": []
  }
}
JSON

    # --- slash commands ---
    _gen_commands "$commands_dir" "$stack_str"

    echo "$claude_dir"
}

#-------------------------------------------------------------------------------
# run_analysis — main entry point
# Sets globals: TEAM_KEYS, STACK_STR, CLAUDE_DIR
# $1=requirements  $2=project_type  $3=workspace  $4=project_name
#-------------------------------------------------------------------------------
run_analysis() {
    local requirements="$1"
    local project_type="${2:-}"
    local workspace="${3:-}"
    local project_name="${4:-}"

    TEAM_KEYS=$(detect_team "$requirements" "$project_type")
    STACK_STR=$(detect_stack "$requirements" "$project_type")

    if [ -n "$workspace" ] && [ -n "$project_name" ]; then
        CLAUDE_DIR=$(generate_claude_config \
            "$workspace" "$project_name" "$project_type" \
            "$TEAM_KEYS" "$STACK_STR" "$requirements")
    fi
}
