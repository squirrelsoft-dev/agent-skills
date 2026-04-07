# Subagent Work Workflow

This diagram shows the `/work` command flow using the subagent orchestration mode, where each task runs in an isolated git worktree with parallel implementation and sequential quality gates.

```mermaid
flowchart TD
    Start(["/work feature-name --all"]) --> Parse["Parse .claude/tasks/feature-name.md<br/>Extract groups with dependencies"]
    Parse --> VerifySpecs{"Specs exist for<br/>all incomplete tasks?"}
    VerifySpecs -- No --> StopSpecs["List missing specs<br/>Suggest /spec first"]
    VerifySpecs -- Yes --> Enqueue["Create TaskCreate entries<br/>per group in dependency order"]

    Enqueue --> GroupLoop["Next available group"]

    subgraph GroupPipeline ["Pipeline — per group"]
        direction TB
        
        subgraph Phase1 ["Phase 1 — Setup"]
            GitSetup["Spawn Git Expert agent<br/>Operation: SETUP"]
            GitSetup --> CreateBranch["Create feature branch<br/>feat/feature-group-N"]
            CreateBranch --> CreateWorktrees["Create worktree per task<br/>work/feature-group-N-1, N-2..."]
            CreateWorktrees --> SetupDone["GIT_SETUP_COMPLETE"]
        end

        subgraph Phase2 ["Phase 2 — Implement"]
            direction LR
            Impl1["Implementer 1<br/>worktree branch 1<br/>run_in_background: true"]
            Impl2["Implementer 2<br/>worktree branch 2<br/>run_in_background: true"]
            ImplN["Implementer N<br/>worktree branch N<br/>run_in_background: true"]
        end

        SetupDone --> Phase2

        subgraph Phase3 ["Phase 3 — Quality Gates (per branch)"]
            QA["For each successful branch:<br/>Spawn Quality agent"]
            QA --> Gate1["Simplify"]
            Gate1 --> Gate2["Review"]
            Gate2 --> Gate3["Security Review"]
            Gate3 --> Gate4["Security Scan"]
            Gate4 --> QAReport["QA_REPORT: PASS/FAIL"]
            QAReport --> UserApprove{"User approves<br/>merge?"}
        end

        Phase2 --> Phase3

        subgraph Phase4 ["Phase 4 — Merge"]
            GitMerge["Spawn Git Expert agent<br/>Operation: MERGE"]
            GitMerge --> MergeBranches["Merge approved branches<br/>into feature branch"]
            MergeBranches --> MarkTasks["Mark tasks complete<br/>in task file"]
            MarkTasks --> Cleanup["Remove worktrees<br/>Delete work branches"]
        end

        UserApprove -- "Merge" --> Phase4
        UserApprove -- "Skip" --> Phase4

        subgraph Phase5 ["Phase 5 — Verify"]
            GitVerify["Spawn Git Expert agent<br/>Operation: VERIFY"]
            GitVerify --> RunBuild["npm run build"]
            RunBuild --> RunLint["npm run lint"]
            RunLint --> RunTypecheck["npm run typecheck"]
            RunTypecheck --> RunTest["npm test"]
            RunTest --> VerifyReport["GIT_VERIFY_COMPLETE"]
        end

        Phase4 --> Phase5
    end

    GroupLoop --> GroupPipeline
    Phase5 --> GroupDone{"More groups?"}
    GroupDone -- Yes --> GroupLoop
    GroupDone -- No --> Summary["Print final summary<br/>with all group results"]
```
