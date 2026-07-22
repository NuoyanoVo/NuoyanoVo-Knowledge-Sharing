# Course Report HTML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local interactive HTML page from the course report schedule, including expert popups, downloaded expert images, and downloaded course file resources.

**Architecture:** A PowerShell scraper logs into the Moodle course, extracts report sections, expert detail pages, and resource links, downloads binary assets into local folders, and writes a static `index.html` for GitHub Pages. A separate verifier checks the generated artifact and local assets.

**Tech Stack:** PowerShell, Moodle HTML parsing with regular expressions plus HTML decoding, static HTML/CSS/JavaScript.

---

### Task 1: Artifact Verifier

**Files:**
- Create: `tests/verify_course_html.ps1`

- [ ] **Step 1: Write the failing verifier**

Create a verifier that checks `index.html`, table rows, expert modal data, avatar directory, and resources directory.

- [ ] **Step 2: Run verifier to verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File .\tests\verify_course_html.ps1`
Expected: FAIL because `index.html` does not exist yet.

### Task 2: Scraper And Generator

**Files:**
- Create: `tools/generate_course_html.ps1`
- Create: `assets/experts/`
- Create: `assets/resources/`
- Create: `index.html`

- [ ] **Step 1: Implement login and course extraction**

Read the Moodle login token, authenticate with the provided account, fetch the course page, and extract sections and report activities.

- [ ] **Step 2: Implement expert profile extraction**

For each report page, extract page body text and first usable image. Save the image locally when present; otherwise use an inline initial avatar in the generated HTML.

- [ ] **Step 3: Implement file resource download**

Find `modtype_resource` activities, follow their Moodle resource URLs, resolve final file URLs, and save files into `assets/resources/`.

- [ ] **Step 4: Generate static HTML**

Write `index.html` with a report table, local avatar thumbnails, resource links, and a click-to-open expert introduction modal.

### Task 3: Verification

**Files:**
- Read: `index.html`
- Read: `assets/experts/`
- Read: `assets/resources/`
- Run: `tests/verify_course_html.ps1`

- [ ] **Step 1: Run the verifier**

Run: `powershell -ExecutionPolicy Bypass -File .\tests\verify_course_html.ps1`
Expected: PASS with 18 report/activity rows and local asset/resource checks.

- [ ] **Step 2: Inspect generated summary**

Read the verifier output and confirm generated counts before final response.
