# ATT Execution Review — Project Context

## Overview

Single-page HTML application (`index.html`, ~2192 lines) that serves as an **Execution Review workbench** for Test Plan Executions (TPE) in the WTW Automated Testing Tool. The app is a UI prototype/mockup using hardcoded sample data from Dataverse, designed to be embedded within a PowerApps-style shell.

## Tech Stack

- **Bootstrap 5.3.3** — layout, modals, badges, responsive grid
- **Bootstrap Icons 1.11.3** — iconography
- **Highlight.js 11.11.1** — SQL syntax highlighting (atom-one-dark theme)
- **Vanilla JS** — all logic in a single `<script>` block, no framework

## Architecture

Everything lives in one `index.html` file with three sections:
1. **CSS** (`<style>`) — custom variables (`--wtw-purple`, `--powerapps-purple`, etc.), PowerApps shell chrome, collapsible sections, results tables, fullscreen SQL modal
2. **HTML** — two screens + modals
3. **JavaScript** — data model, state, DOM elements, functions, event handlers

### Screen Structure

| Screen | Purpose |
|---|---|
| `screenWelcome` | Landing page showing TPE summary (executor, client, dates, pass/fail counts, reviewer). "Start Review" button enters workbench. |
| `screenReview` | Main workbench with left sidebar (test case list) and right detail panel with collapsible accordion sections. |

### PowerApps Shell

- **Header** (48px, purple `#742774`) — simulates PowerApps top bar
- **Sidebar** (200px, collapsible) — navigation items: Test Plans, Test Cases, Test Plan Executions, etc.
- **Main area** — hosts the two screens

## Data Model

### Source

Sample data pulled from **Dataverse** environment using MCP tools:
- TPE GUID: `cdfdfff5-6148-f111-bec6-6045bdef4434` (TPE-2778)
- Key Dataverse entities: `att_atttestplanexecution`, `att_atttcexecution`, `att_atttestcase`, `att_atttemplate`, `att_atttemplateversion`, `att_testcasedetails`

### `testPlanExecution` Object

Top-level object containing:
- **Identity**: `name`, `executionId` (TPE-2778), `testPlanId`, `clientName` ("Automated Testing Tool (H-BC4)")
- **Execution metadata**: `executor` ("Alex Tonog"), `executionDate`, `environment` ("QA"), `planYear` (2026), `status` ("Results Review")
- **Aggregates**: `totalTestCases` (7), `totalPassed` (0), `totalFailed` (6), `totalAwaitingDecision` (1)
- **Runtime parameters**: array of `{ Name, Value, DataType, CanShowTestcaseUI }` — TPE-level params (PlanYear, SpecialGroupId, PersonId)
- **Review state**: `signedOff`, `signOffReviewer`, `sentToTracker`, etc.
- **`testCaseExecutions`**: array of 7 TCE objects

### Test Case Executions (7 records)

| # | TCE ID | Name | Template | Type | Result | Notable |
|---|---|---|---|---|---|---|
| 1 | TCE-3713 | test | Mapping - GroupID (TMPV-1448) | SQL | Failed | SQL syntax error, has `additionalDetails` stack trace |
| 2 | TCE-3715 | Test-ActionBased-01 | ActionBased | Action | Failed | Full 6-phase pipeline, no manual verification |
| 3 | TCE-3716 | test-actionbased-alexis-2 | ActionBased | Action | Failed | `manualVerificationComment`: "Notes manual verify" |
| 4 | TCE-3717 | test-sql-based-alex-1 | Calc Compare - AE | SQL | User Validation | Complex SQL (calc analysis), 5 passing results, `tab-calccompare` visible |
| 5 | TCE-3712 | basic life - imputed | Imputed Income - Basic Life (TMPV-1396) | SQL | Failed | Imputed income calculation, 2 negative failures |
| 6 | TCE-3718 | test-actionbased-alexis-1 | ActionBased | Action | Failed | `manualVerificationComment`: "manual test" |
| 7 | TCE-3714 | aa_group_mapping_6 | Mapping - PriceGroup (TMPV-1450) | SQL | Failed | Has `conditions` JSON and `whereClause` |

### TCE Object Shape

```
{
  name, testcaseId, testcaseExecutionId, testcaseGuid,
  templateName, templateVersion, environment,
  manualVerificationComment,          // ActionBased only
  executionResult, executionResultCode, executedBy, executionDate,
  executionRemarks, executionStatus,
  reviewStatus ("PENDING"|"APPROVED"|"OVERRIDDEN"|"FAILED"|"RE_EXECUTE"),
  reviewRemarks, overrideComment,
  resultRef, logReferenceId, additionalDetails,
  executionInstance, conditions, formattedWhereClause, whereClause,
  query,                              // SQL query string (SQL-based)
  parameters: [{ Name, Value, DataType, CanShowTestcaseUI }],
  results: [{ name, expected, actual, remarks }],
  userValidation: { status, comments },
  phases: [{ name, displayName, code, status, message, testStatus,  // ActionBased only
    steps: [{ name, displayName, status, message, testStatus, link,
      variables: [{ name, displayName, value, type, required, include, operator, description }]
    }]
  }],
  history: [{ instance, date, result, executor }]
}
```

## UI Components — Review Workbench

### Header Bar

- **Toggle sidebar** button (burger icon)
- **Plan title** + execution ID
- **Environment badge** (`envBadge`) — inline, shows per-TCE environment
- **Progress badge** — "X / 7 reviewed"
- **Request Peer Review** button (was "Sign Off") — enabled when all TCEs reviewed
- **Send to Tracker** button — hidden until peer review requested
- **Back** button

### Context Bar (sticky, below header)

Shows Original Person ID, Cloned Person ID, Execution Status, Execution Result with color coding.

### Phase Failure Alert

Red alert banner for failed phases (ActionBased) or SQL execution errors. Shows prominently without requiring tab navigation.

### Left Sidebar — Test Case List

- Search input
- Filter buttons: All, Pending, Failed, Approved, Overridden (with counts)
- Bulk action bar (bulk approve Passed tests)
- TC rows sorted: Failed first → User Validation → Passed
- Rows show name, TC ID, template name, result badge, review status badge

### Right Panel — Collapsible Accordion Sections

#### Non-ActionBased (SQL) Test Cases

| Order | Section | Visibility | Description |
|---|---|---|---|
| 1 | General Information | Always | Two-column grid: name, template, TCE/TC IDs, ref ID, status, result, executor, date, remarks. Error details expandable. |
| 2 | Runtime Parameters | `tab-sql` | ALL TCE parameters (no filtering). Populated by `populateRuntimeParams()`. |
| 3 | Setup Parameters | `tab-sql` | Filtered: only params where `CanShowTestcaseUI != "No"`. Populated by `populateParams()`. |
| 4 | Verification Result | `tab-sql` | Results table with criteria name, expected, actual, operator, result. Sortable, filterable (all/failures only). Failures highlighted red. |
| 5 | User Validation | `tab-sql tab-calccompare` | Only visible for Calc Compare templates. Radio buttons (User Validation/Pass/Failed) + comments textarea. |
| 6 | Condition | `tab-sql` | WHERE clause display + parsed JSON condition rules. |
| 7 | Query | `tab-sql` | SQL editor with syntax highlighting, copy to clipboard, fullscreen maximize. |

#### ActionBased Test Cases

| Order | Section | Visibility | Description |
|---|---|---|---|
| 1 | General Information | Always | Same as non-ActionBased |
| 2 | Manual Verification Instruction | `tab-action` | Shows `manualVerificationComment` or "No instructions available" |
| 3 | Verification Results | `tab-action` | Same table format as Verification Result but includes BenId/OptionId columns |
| 4 | Phase Results | `tab-action` | Phases table with expandable variables (Show Variables checkbox). Phases: Parameter→TargetPerson→Precondition→Execution→Verification→Cleanup |

### Actions Section (below accordion)

- **Pending tests**: Radio buttons for review decision
  - Failed/UV: Override (requires comment), Re-execute, Leave Failed
  - Passed: Approved (default), Re-execute
- **Review Remarks** textarea (required for Override)
- **Submit Review** button → auto-advances to next pending TCE

### Completion Banner

Green banner appears when all TCEs reviewed. Lists overridden tests. "Request Peer Review" button.

## Key Functions

| Function | Purpose |
|---|---|
| `initWelcome()` | Populates welcome screen with TPE data |
| `renderList()` | Renders left sidebar TCE list with filters/search/sort |
| `getVisibleIndexes()` | Returns filtered+sorted array of TCE indices |
| `selectTestCase(idx)` | Main detail population — calls all populate* functions |
| `configureTabsForTemplate(tc)` | Shows/hides `tab-sql`, `tab-action`, `tab-calccompare` sections |
| `populateRuntimeParams(params)` | Fills Runtime Parameters table (all params) |
| `populateParams(params)` | Fills Setup Parameters table (filtered by CanShowTestcaseUI) |
| `populateResults(tc)` | Fills Verification Result table (SQL-based) |
| `populateVerificationResults(tc)` | Fills Verification Results table (ActionBased) |
| `populatePhaseResults(tc)` | Fills Phase Results table with steps + variables |
| `populateManualVerification(tc)` | Shows manual verification comment |
| `populateCondition(tc)` | Renders WHERE clause and condition JSON |
| `populateActions(tc)` | Renders review action radios based on execution result |
| `populateUserValidation(tc)` | Sets UV radio buttons and comments |
| `updateContextBar(tc)` | Updates sticky context bar with Person IDs, status |
| `updatePhaseFailureAlert(tc)` | Shows/hides phase failure alert |
| `syncAndHighlightQuery()` | Applies Highlight.js to SQL editor |
| `checkSignOffEligibility()` | Enables/disables peer review + send to tracker buttons |
| `clearDetails()` | Resets all detail panel elements to defaults |
| `moveToNext()` | Auto-advances to next pending TCE after review submission |
| `escapeHtml(str)` | XSS prevention — escapes `& < > " '` |

## Modals

1. **Sign-off Modal** (`signOffModal`) — Reviewer name input, overridden tests warning, confirm peer review request
2. **History Modal** (`historyModal`) — Shows execution history timeline for selected TCE
3. **Fullscreen SQL Modal** (`fullscreenSqlModal`) — Full-viewport SQL editor with syntax highlighting

## Review Flow

1. All TCEs start with `reviewStatus: "PENDING"`
2. Reviewer submits decision → status changes to APPROVED/OVERRIDDEN/FAILED/RE_EXECUTE
3. When all TCEs are APPROVED or OVERRIDDEN → completion banner appears, "Request Peer Review" enabled
4. After peer review requested → "Send to Tracker" button becomes visible and enabled
5. Status label "Completed" was renamed to **"Results Review"** throughout

## CSS Design System

- **Primary purple**: `--wtw-purple: #6f2dbd` (WTW brand)
- **PowerApps purple**: `--powerapps-purple: #742774`
- **Status colors**: success `#14804a`, danger `#b42318`, warning `#b54708`
- **Surface**: white cards with `14px` border radius, subtle borders, soft shadows
- **Font**: Segoe UI system font stack
- **Badge variants**: `badge-soft`, `badge-approved/passed`, `badge-rejected/failed`, `badge-pending`, `badge-overridden`, `badge-reexecute`, `badge-uservalidation`

## File Encoding

- UTF-8 without BOM
- Uses proper Unicode: em dash `—` (U+2014), bullet `•` (U+2022), checkmark `✅` (U+2705)

## Session History Notes

- Accordion sections replaced the original tab-based navigation
- "Sign Off" renamed to "Request Peer Review" everywhere
- "Execution Environment" section removed; environment moved inline to header badge
- "Runtime Parameters" section added (shows ALL params); "Setup Parameters" filtered by `CanShowTestcaseUI`
- User Validation section restricted to Calc Compare templates only (`tab-calccompare` class)
- Sample data replaced from fictional to real Dataverse TPE-2778 data (7 test cases)
- File went through encoding repair (PowerShell `Set-Content` caused UTF-8 double-encoding → fixed)