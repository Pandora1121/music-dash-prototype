# MUSIC DASH Phase 8 Windows Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Godot prototype reproducibly exportable and packageable for 64-bit Windows.

**Architecture:** Store a Windows Desktop export preset in the Godot project, use one PowerShell script to preflight/export/package/smoke-check the build, and document setup and distribution. Keep binaries and archives ignored.

**Tech Stack:** Godot 4.7.2 stable, GDScript project, PowerShell 7/Windows PowerShell, built-in `Compress-Archive`.

**Spec:** `docs/superpowers/specs/2026-10-24-music-dash-phase8-windows-build-design.md`

## Global Constraints

- Target Windows x86_64 using Godot 4.7.2 stable export templates.
- Embed project resources into a single executable and package that executable in a ZIP.
- Keep signing, installer creation, update services, and CI release automation out of scope.
- Never commit generated `.exe`, `.pck`, or `.zip` output.

## Review Focus

- Wrong Godot version: script stops before exporting and states the required version.
- Missing export templates: Godot error is surfaced with an actionable template installation hint.
- Existing build output: rebuild replaces the executable and ZIP without deleting unrelated files.
- Export failure or zero-byte output: ZIP creation and smoke check do not proceed.
- User starts the game from an extracted ZIP: self-contained executable launches without project files.

---

### Task 1: Export preset and build ignore rules

**Files:**
- Create: `export_presets.cfg`.
- Modify: `.gitignore`.

- [x] Add Windows Desktop x86_64 preset with embedded PCK and output path `builds/windows/MusicDash.exe`.
- [x] Ignore only the `builds/` and `dist/` output directories.
- [x] Open project headlessly in Godot editor and verify it parses the preset without script/config errors.

### Task 2: Repeatable Windows export and package script

**Files:**
- Create: `scripts/export_windows.ps1`.
- Create: `tests/test_export_windows_script.ps1`.

- [x] Write script contract tests for unsupported Godot version, export failure, and output packaging behavior.
- [x] Run tests and confirm they fail because the export script is absent.
- [x] Implement `scripts/export_windows.ps1` with configurable Godot executable path, version/preflight checks, release export, output validation, ZIP packaging, and optional headless executable smoke check.
- [x] Run script contract tests; separately verify a missing-template export reports the required setup and does not package a build.

### Task 3: User documentation and final verification

**Files:**
- Modify: `README.md`.
- Verify: project test scripts, main parse check, editor preset startup, export script behavior.

- [x] Document Godot version, official matching template installation, exact export command, output files, and how to run the extracted prototype.
- [x] Run all 23 `tests/test_*.gd` scripts and `scripts/main.gd --check-only`.
- [x] Verify editor startup recognizes the Windows export preset and inspect `git diff --check`.
- [x] Export the release executable, run its headless smoke check, and package the ZIP.
- [x] Commit as `build: add reproducible windows export`.

## Completion Checklist

- [x] Windows preset is recognized and describes the intended x86_64 self-contained build.
- [x] Build script validates, exports, packages, and reports missing prerequisites.
- [x] Export output is excluded from source control.
- [x] README describes the current build workflow.
- [x] Existing gameplay checks remain green.
