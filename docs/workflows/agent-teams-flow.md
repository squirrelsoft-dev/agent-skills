# Agent Teams Work Workflow

This diagram shows the `/work` command flow using agent teams orchestration, where persistent domain teammates collaborate on group-based task execution with shared file ownership boundaries.

```mermaid
flowchart TD
    Start(["/work feature-name --all"]) --> Parse["Parse .claude/tasks/feature-name.md<br/>Extract groups + domains"]
    Parse --> VerifySpecs{"Specs exist for<br/>all incomplete tasks?"}
    VerifySpecs -- No --> StopSpecs["List missing specs<br/>Suggest /spec first"]
    VerifySpecs -- Yes --> Setup["Create feature branch<br/>Create team: work-feature"]

    Setup --> SpawnTeam["Spawn persistent teammates<br/>one per unique domain"]

    SpawnTeam --> GroupLoop["Next available group"]

    subgraph GroupPipeline ["Pipeline — per group"]
        direction TB

        subgraph Assign ["Assign — SendMessage to teammates"]
            direction LR
            Msg1["SendMessage<br/>impl-ui"]
            Msg2["SendMessage<br/>impl-api"]
            MsgN["SendMessage<br/>impl-data"]
        end

        subgraph Implement ["Implement — Teammates work in parallel"]
            direction LR
            TM1["impl-ui<br/>implements group tasks<br/>within owned files only"]
            TM2["impl-api<br/>implements group tasks<br/>within owned files only"]
            TMN["impl-data<br/>implements group tasks<br/>within owned files only"]
        end

        Assign --> Implement

        Wait["Wait for GROUP_COMPLETE<br/>from each domain teammate<br/>1 message per domain"]
        Implement --> Wait

        subgraph QualityGate ["Quality Gate Agent"]
            direction TB
            QG1["Gate 1: Lint"] --> Fix1{"Pass?"}
            Fix1 -- No --> Spawn1["Fix agent"] --> QG1
            Fix1 -- Yes --> QG2["Gate 2: Typecheck"] --> Fix2{"Pass?"}
            Fix2 -- No --> Spawn2["Fix agent"] --> QG2
            Fix2 -- Yes --> QG3["Gate 3: Build"] --> Fix3{"Pass?"}
            Fix3 -- No --> Spawn3["Fix agent"] --> QG3
            Fix3 -- Yes --> QG4["Gate 4: Test"] --> Fix4{"Pass?"}
            Fix4 -- No --> Spawn4["Fix agent"] --> QG4
            Fix4 -- Yes --> QG5["Gate 5: Simplify"] --> Fix5{"Pass?"}
            Fix5 -- No --> Spawn5["Fix agent"] --> QG5
            Fix5 -- Yes --> QG6["Gate 6: Review"] --> Fix6{"Pass?"}
            Fix6 -- No --> Spawn6["Fix agent"] --> QG6
            Fix6 -- Yes --> QG7["Gate 7: Security Review"] --> Fix7{"Pass?"}
            Fix7 -- No --> Spawn7["Fix agent"] --> QG7
            Fix7 -- Yes --> QG8["Gate 8: Security Scan"] --> Fix8{"Pass?"}
            Fix8 -- No --> Spawn8["Fix agent"] --> QG8
            Fix8 -- Yes --> QGReport["QUALITY_GATE_REPORT<br/>PASS / FAIL"]
        end

        Wait --> QualityGate

        HandleQA{"Overall<br/>PASS?"}
        QGReport --> HandleQA
        HandleQA -- Yes --> MarkComplete["Mark group task complete<br/>TaskCompleted hook fires:<br/>format + task-summary"]
        HandleQA -- No --> UserDecide{"User decides"}
        UserDecide -- "Accept" --> MarkComplete
        UserDecide -- "Stop" --> StopAll["Stop processing"]
    end

    GroupLoop --> GroupPipeline
    MarkComplete --> MoreGroups{"More groups?"}
    MoreGroups -- Yes --> GroupLoop
    MoreGroups -- No --> Commit["Stage + commit all changes<br/>git commit -m feat: title"]
    Commit --> Shutdown["Shutdown teammates<br/>Delete team"]
    Shutdown --> Summary["Print final summary"]
```
