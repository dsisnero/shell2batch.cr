## How to reason about this repository

Short summary
- Purpose: a small Crystal library + CLI that converts POSIX shell scripts to Windows batch (.bat) scripts.
- Main components: CLI entry (`src/shell2batch.cr`), conversion logic (`src/shell2batch/converter.cr`), examples in `examples/`, and specs in `spec/`.

Key design decisions an AI should respect
- The converter is implemented as a single class `Shell2Batch::Converter` that tokenizes lines and maps common shell commands to batch equivalents. Keep changes localized to `converter.cr` for most feature work.
- The project favors explicit, rule-based conversions (case handling in `convert_line`) rather than full AST parsing. Add new command mappings by following the existing `when "cmd"` pattern.

Developer workflows (commands you can run locally)
- Build executable: `shards build --release --static` (binary appears in `bin/`).
- Run CLI against a script: `bin/shell2batch path/to/script.sh` or `crystal run src/shell2batch.cr -- path/to/script.sh`.
- Run tests/specs: `crystal spec` (spec files live in `spec/`).

Project-specific conventions and patterns
- Single-file converter: `src/shell2batch/converter.cr` contains most logic. When adding support for a shell command:
  - Add a `when "cmd"` branch inside `convert_line` returning a 5-tuple: `{windows_command, flag_mappings, pre_arguments, post_arguments, modify_path_separator}` (see existing entries like `cp`, `rm`, `ln`, `curl`).
  - Use `flags_mappings` as an Array(Tuple(String, String)) where the first element is a regex-like pattern to match shell flags and the second is the windows replacement (see `cp`/`rm`).
  - Use `pre_arguments` and `post_arguments` to inject fixed arguments before/after the converted arguments.

- Variable handling: `replace_vars`, `replace_full_vars`, and `replace_partial_vars` implement conversions from `$VAR`/`${VAR}` to `%VAR%`. Note special-casing for numeric and positional parameters (e.g., `$1` -> `%1`, `$@` -> `%*`) and `$(dirname $0)` -> `%~dp0`.

- Conditionals: `convert_if_statement` expects shell `if [ ... ]; then` style structures and emits batch `if ... ( ... )` blocks. Keep multi-line control flow intact by delegating to `convert_if_statement`.

Integration points and external dependencies
- No external services. Uses Crystal stdlib and `shards` for dependency management. The code references `bitsadmin` and PowerShell in generated batch files for downloads/archives but does not call external services at build time.

Tests and examples
- Examples are in `examples/` (e.g., `example.sh`, `app-neovim.sh`) and a small usage snippet appears in `README.md`.
- Specs live under `spec/` and are runnable with `crystal spec`.

Code-editing tips for an AI
- Small, focused edits are better than large rewrites. Modify `converter.cr` in-place and add unit/spec coverage for any new command mapping in `spec/`.
- Preserve the 5-tuple return shape from `convert_line` branches; tests and other code expect the tuple unpacking that follows.
- When changing path handling, be careful with `modify_path_separator` which toggles replacing `/` with `\` except for URLs.

Examples to copy-paste when making changes
- New conversion branch skeleton:

```crystal
when "newcmd"
  {"windows_equivalent", [] of Tuple(String,String), [] of String, [] of String, true}
```

Follow-up questions you should ask the maintainer
- Which Windows behaviors or edge-cases should be prioritized (e.g., advanced quoting, subshells, process substitution)?
- Is supporting more complex shell constructs (functions, loops, here-docs) desired, or should we keep the converter focused on common CLI patterns?

If anything in this file is unclear or you'd like more detail (examples, test locations, or frequently used scripts), tell me which area to expand and I'll iterate.
