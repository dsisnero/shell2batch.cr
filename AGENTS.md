# AGENTS.md

## Commands
- **Build**: `shards build --release --static` (binary in `bin/`) or `crystal build src/shell2batch.cr` or `shards build`
- **Run CLI**: `crystal run src/shell2batch.cr -- path/to/script.sh` or `bin/shell2batch path/to/script.sh`
- **Run all tests**: `crystal spec`
- **Run single test**: `crystal spec spec/converter_spec.cr` (or any specific spec file)
- **Run**: `crystal run`
- **Run**: `shards`
- **Run**: `ruby`
- **Run**: `rm`

## Architecture
- **CLI entry**: `src/shell2batch.cr` - main executable
- **Core logic**: `src/shell2batch/converter.cr` - single-file converter class with command mappings
- **Specs**: `spec/` - test files using Crystal spec framework
- **Examples**: `examples/` - sample shell scripts for conversion testing
- Simple rule-based converter, not AST-based; commands are mapped in `convert_line` via `when "cmd"` branches

## Code Style & Conventions
- **Adding commands**: In `converter.cr`, add `when "newcmd"` branch returning 5-tuple: `{windows_command, flag_mappings, pre_arguments, post_arguments, modify_path_separator}`
- **Flag mappings**: Use `Array(Tuple(String, String))` where first element is shell flag pattern, second is Windows replacement
- **Variables**: Shell `$VAR`/`${VAR}` → Batch `%VAR%`; positional params like `$1` → `%1`, `$@` → `%*`
- **Preserve tuple shape**: All `convert_line` branches must return the same 5-tuple structure
- **Small focused edits**: Modify `converter.cr` in-place, add spec coverage for new mappings
- **Path handling**: Use `modify_path_separator` to control `/` → `\` conversion (false for URLs)

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

## Issue Tracking

This project uses **bd (beads)** for issue tracking.
Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

**IMPORTANT: Use bd for task tracking instead of the todo tool.**
- Create issues with `bd create` for work items
- Track progress with `bd ready` and `bd close`
- Use `bd sync` to keep issues in sync with git

**Quick reference:**
- `bd ready` - Find unblocked work
- `bd create "Title" --type task --priority 2` - Create issue
- `bd close <id>` - Complete work
- `bd sync` - Sync with git (run at session end)

For full workflow details: `bd prime`
