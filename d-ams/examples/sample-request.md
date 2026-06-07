# Sample User Request

**User Goal:** Create a robust Web API for managing an autonomous agent fleet.

## Technical Specifications
*   **Leader Agent:** Gemini (CLI Orchestrator).
*   **Backend:** FastAPI (Python).
*   **Database:** PostgreSQL.
*   **Key Features:**
    *   CRUD operations for Agents (Name, Role, Status).
    *   Ability to assign a Task to an Agent.
    *   Query agents by their current status (Idle, Busy, Offline).
    *   Automatic logging of all agent activities.

## Request Prompt for Leader Agent
> "Hãy tự động tạo một web app quản lý agents với leader agent Gemini, backend là FastAPI, database PostgreSQL. Hệ thống cần có các API để quản lý thông tin agent, phân công task và theo dõi trạng thái. Đảm bảo có đầy đủ unit tests và tài liệu API (Swagger)."
