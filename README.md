<div align="center">
  <h1>agents_manager</h1>
  <p><strong>Two autonomous AI tools in one repo</strong></p>
  <p>
    <img src="https://img.shields.io/badge/platform-linux-blue?style=flat-square" />
    <img src="https://img.shields.io/badge/shell-bash-yellow?style=flat-square" />
    <img src="https://img.shields.io/badge/license-Apache%202.0-green?style=flat-square" />
  </p>
</div>

---

## AutoBuilder — Autonomous Agent Pipeline (new)

**AutoBuilder** takes a project description (text or file) and runs a fully autonomous 6-stage pipeline powered by Claude Code CLI to generate a complete, working application with no user interaction.

### Quick start

```bash
# From a text description
./autobuilder/build.sh "React todo app with authentication and dark mode"

# From a requirements file
./autobuilder/build.sh --file requirements.pdf
./autobuilder/build.sh --file specs.docx
./autobuilder/build.sh --file description.txt
```

### How it works

1. Input parser converts `.txt`, `.md`, `.pdf`, or `.docx` to plain text
2. A workspace is created at `./output/YYYYMMDD_HHMMSS_<slug>/`
3. Six agents run sequentially, each building on the previous output:

| Stage | Agent | Input | Output |
|-------|-------|-------|--------|
| 01 | Analyst | requirements.txt | analysis.md |
| 02 | Architect | requirements + analysis | architecture.md |
| 03 | Planner | all above | build-plan.md |
| 04 | Builder | all above | `project/` (full app) |
| 05 | Reviewer | requirements + architecture + files | REVIEW_REPORT.md |
| 06 | QA | requirements + files | QA_REPORT.md + test.sh |

### Directory layout

```
autobuilder/
├── build.sh                     <- main entry point
├── config/
│   └── settings.conf
├── lib/
│   ├── ui.sh                    <- terminal UI (colors, progress, banners)
│   └── logging.sh               <- logging functions
├── input/
│   └── parser.sh                <- .txt/.md/.docx/.pdf -> plain text
├── agents/
│   ├── run.sh                   <- wrapper to call `claude` CLI
│   └── prompts/
│       ├── analyst.txt
│       ├── architect.txt
│       ├── builder.txt
│       ├── reviewer.txt
│       └── qa.txt
├── pipeline/
│   ├── runner.sh                <- orchestrates all stages
│   └── stages/
│       ├── 01-analyze.sh
│       ├── 02-architect.sh
│       ├── 03-plan.sh
│       ├── 04-build.sh
│       ├── 05-review.sh
│       └── 06-qa.sh
└── workspace/
    └── manager.sh               <- create/manage workspace dirs

output/                          <- generated apps land here
```

### Requirements

- `claude` (Claude Code CLI) in `$PATH`
- For PDF input: `pdftotext` (poppler-utils) or `pip install pypdf`
- For DOCX input: `pip install python-docx` or `pip install docx2txt`

---

## D-AMS Agent Manager (original)

<div align="center">
  <h2>🤖 D-AMS Agent Manager</h2>
  <p><strong>Dynamic Agent Management System</strong></p>
  <p>Orchestrate terminal AI agents — Claude Code, Gemini, OpenCode — as a coordinated team in Kitty terminal</p>
</div>

### Giới thiệu

**D-AMS Agent Manager** là công cụ orchestration chạy trong terminal, giúp bạn quản lý và điều phối các AI coding agent như một đội ngũ phát triển phần mềm thực thụ.

Tool hoạt động trên **Kitty terminal** (Linux), mỗi agent được khởi chạy trong một tab/cửa sổ riêng, tuân theo quy trình 6 bước từ lập kế hoạch đến bàn giao sản phẩm.

#### Managed Agents

| Agent | Vai trò | Command |
|-------|---------|---------|
| 🟣 **Claude Code** (Anthropic) | Backend Developer / Systems Programmer | `claude` |
| 🔵 **Gemini** (Google) | Leader Agent / Tech Lead | `gemini` |
| 🟢 **OpenCode** (Open-source) | QA/QC Engineer / Frontend Developer | `opencode` |

---

### Tính năng

- **Interactive TUI** — Giao diện menu trực quan để quản lý dự án, agents và công việc
- **Kitty Integration** — Mỗi agent chạy trong một tab/cửa sổ Kitty riêng
- **Team Assembly** — Triệu tập cả 3 agents chỉ với một lệnh
- **Task Assignment** — Giao việc cho từng agent kèm logging đầy đủ
- **Session Logging** — Mọi hành động đều được ghi lại theo thời gian thực
- **Workflow Tracking** — Theo dõi tiến độ qua 6 phase của D-AMS

---

### Quick Start

```bash
# Clone & install
git clone https://github.com/nguyenthuongaz9/agents_manager.git
cd agents_manager
chmod +x install.sh agent-manager.sh
./install.sh
```

Sau khi cài đặt, dùng lệnh `agents` từ bất kỳ đâu:

```bash
agents                    # Chế độ tương tác (khuyên dùng)
agents --assemble         # Mở cả 3 agent trong Kitty tabs
agents --launch CLAUDE    # Mở một agent cụ thể
agents --log              # Xem session log gần nhất
```

Hoặc load toàn bộ layout (Manager + 3 agents):

```bash
kitty --session config/d-ams.kitty.session
```

---

### Workflow

Tool vận hành theo 6 phase:

| Phase | Mô tả |
|-------|-------|
| 1. Intake & Analysis | Xác định phạm vi dự án, yêu cầu |
| 2. Team Assembly | Khởi chạy agents trong Kitty tabs |
| 3. Planning & Tasking | Phân tích kiến trúc, giao việc |
| 4. Execution & Review | Agents thực thi nhiệm vụ |
| 5. Domain-Specific QA | Kiểm thử chất lượng |
| 6. Delivery | Đóng gói và bàn giao sản phẩm |

---

### Cấu trúc thư mục

```
agent-manager/
├── agent-manager.sh        # Main orchestrator
├── install.sh              # Script cài đặt
├── config/
│   ├── agents.conf         # Định nghĩa các agents
│   └── d-ams.kitty.session # Kitty session layout
├── lib/
│   ├── ui.sh               # Giao diện terminal (menu, màu sắc)
│   ├── kitty.sh            # Tích hợp Kitty terminal
│   └── logging.sh          # Ghi log session
└── sessions/               # Lưu trữ log

agent-management-system/    # Tài liệu kiến trúc D-AMS
├── docs/                   # Architecture, agents, teams, workflow
├── prompts/                # System prompts cho từng agent role
└── examples/               # Mẫu yêu cầu dự án
```

---

### Yêu cầu

- Linux với [Kitty terminal](https://sw.kovidgoyal.net/kitty/)
- Ít nhất một trong các lệnh: `claude`, `gemini`, `opencode` có trong `$PATH`

---

## License

Apache License 2.0
