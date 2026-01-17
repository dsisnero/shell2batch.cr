# Shell2Batch Extension Plan: Bash Scripts & Makefile Support

## Current State Analysis

**✅ COMPLETED WORK:**
- **Modular Architecture**: Created base_converter.cr, shell_converter.cr, command_mappings.cr, common_utils.cr
- **File Type Detection**: Implemented automatic detection of shell scripts vs Makefiles
- **Enhanced CLI**: Added --type and --format options with auto-detection
- **Command Mapping System**: Structured database for command mappings with CommandMapping struct
- **Bug Fixes**: Fixed variable replacement, ln command, touch command, line endings, and multi-line handling
- **Test Suite**: All tests pass with 0 failures, 7 pending tests
- **Shell Converter**: Fully functional with hybrid approach (CommandMappings + handler methods)

**Current Architecture:**
- **CLI Entry**: `src/shell2batch.cr` - Enhanced with file type detection and options
- **Core Logic**: `src/shell2batch/converter.cr` - Delegates to appropriate converter based on file type
- **Shell Converter**: `src/shell2batch/shell_converter.cr` - Uses CommandMappings + handler methods
- **Makefile Converter**: `src/shell2batch/makefile_converter.cr` - ✅ COMPLETE with AST parser and variable expansion
- **Command Mapping**: Hybrid approach - CommandMappings for simple commands, handler methods for complex cases
- **Variable Handling**: Converts `$VAR` → `%VAR%`, `${VAR}` → `%VAR%`, `$(dirname $0)` → `%~dp0`
- **Path Conversion**: `/` → `\` (except for URLs)
- **Conditionals**: Basic `if` statement conversion support
- **Admin Privileges**: Automatic elevation for sudo/mklink commands
- **Download Function**: Built-in curl → bitsadmin conversion with function

**REMAINING WORK:**
- **Makefile Support**: ✅ COMPLETE - MakefileConverter fully implemented with parser and tests
- **Additional Commands**: Missing complex bash commands (sed, awk, tar, etc.) - basic commands implemented
- **Advanced Features**: Shell functions, loops, case statements
- **PowerShell Output**: Format option not yet implemented

## Extension Goals

### Phase 1: Enhanced Bash Script Support
1. **Add missing common bash commands**
   - `sed`, `awk`, `find`, `tar`, `gzip`, `gunzip`, `chmod`, `chown`
   - `source`/`.` → `call`
   - `which` → `where`
   - `date` → Windows date commands

2. **Improve shell script parsing**
   - Better handling of multi-line commands
   - Support for shell functions
   - Enhanced variable expansion
   - Array and string operations

3. **Add advanced shell features**
   - `for` loops → `for` loops
   - `while` loops → `:while` labels
   - `case` statements → nested `if` statements
   - Subshells and command substitution

### Phase 2: Makefile Support

1. **Makefile Parser**
   - Parse Makefile syntax (targets, dependencies, recipes)
   - Handle Makefile variables (`VAR = value`)
   - Support for Makefile functions (`$(shell ...)`, `$(wildcard ...)`)
   - Handle Makefile conditionals (`ifeq`, `ifneq`, `ifdef`)

2. **Makefile to Windows Batch Conversion**
   - Convert Makefile targets to batch labels
   - Convert dependencies to batch conditional execution
   - Convert Makefile recipes to batch commands
   - Handle Makefile variables → batch variables
   - Support for common Makefile patterns

3. **Makefile-Specific Features**
   - `.PHONY` targets handling
   - Pattern rules (`%.o: %.c`)
   - Automatic variables (`$@`, `$<`, `$^`)
   - Makefile includes

### Phase 3: Advanced Features

1. **Cross-Platform Compatibility**
   - Detect shell script type (bash, sh, zsh)
   - Handle platform-specific differences
   - Generate PowerShell alternatives where appropriate

2. **Error Handling & Validation**
   - Syntax validation for input files
   - Warning system for unsupported features
   - Fallback strategies for complex commands

3. **CLI Enhancements**
   - File type detection (auto-detect Makefile vs shell script)
   - Output format options (batch, PowerShell)
   - Interactive mode for complex conversions

## Implementation Strategy

### Architecture Changes ✅ IMPLEMENTED

1. **Modular Converter Structure** ✅
   ```
   src/shell2batch/
   ├── converter.cr          # Main converter with file type detection
   ├── base_converter.cr     # Abstract base class with common utilities
   ├── shell_converter.cr    # Shell-specific logic ✅
   ├── makefile_converter.cr # Makefile-specific logic (TODO)
   ├── common_utils.cr       # Shared utilities ✅
   └── command_mappings.cr   # Command mapping database ✅
   ```

2. **File Type Detection** ✅
   - Detect file type by extension and content ✅
   - Shell scripts: `.sh`, `.bash`, shebang detection ✅
   - Makefiles: `Makefile`, `makefile`, `.mk` ✅

3. **Enhanced CLI** ✅
   - Add `--type` option for explicit file type ✅
   - Add `--output-format` option ✅
   - Better error reporting ✅

### Command Mapping Database ✅ IMPLEMENTED

Structured command mapping system implemented:

```crystal
struct CommandMapping
  property shell_command : String
  property windows_command : String
  property flag_mappings : Array(Tuple(String, String))
  property pre_arguments : Array(String)
  property post_arguments : Array(String)
  property modify_path_separator : Bool
  property makefile_support : Bool
end
```

### Makefile Parser

Implement a Makefile parser that:
- Parses targets and dependencies
- Handles variable assignments
- Processes conditionals and functions
- Converts to equivalent batch structure

## Development Phases

### Phase 1: Foundation (Week 1) ✅ COMPLETE
- [x] Create modular converter structure
- [x] Implement file type detection
- [x] Add missing common bash commands
- [x] Write comprehensive tests

### Phase 2: Makefile Support (Week 2) ✅ COMPLETE
- [x] Implement Makefile parser
- [x] Create Makefile converter
- [x] Handle Makefile variables and functions
- [x] Add Makefile-specific tests

### Phase 3: Advanced Features (Week 3)
- [ ] Add shell function support
- [ ] Implement loop conversion
- [x] Add error handling and validation
- [x] Enhance CLI with new options

### Phase 4: Polish & Documentation (Week 4)
- [ ] Performance optimization
- [ ] Comprehensive documentation
- [ ] Example Makefile conversions
- [ ] Release preparation

## Testing Strategy

1. **Unit Tests**
   - Individual command mappings
   - Variable expansion
   - Path conversion
   - Makefile parsing

2. **Integration Tests**
   - Complete shell script conversions
   - Complete Makefile conversions
   - Real-world examples

3. **Regression Tests**
   - Ensure existing functionality preserved
   - Test edge cases and error conditions

## Success Metrics

- **Coverage**: 90%+ test coverage
- **Performance**: Sub-second conversion for typical files
- **Compatibility**: Support for 95%+ common shell/Makefile patterns
- **Usability**: Clear error messages and helpful documentation

## Risks & Mitigations

1. **Complex Makefile Features**
   - Risk: Some Makefile features may not have direct batch equivalents
   - Mitigation: Provide clear warnings and workarounds

2. **Performance**
   - Risk: Large Makefiles may slow conversion
   - Mitigation: Optimize parser and use efficient data structures

3. **Platform Differences**
   - Risk: Some shell features have no Windows equivalent
   - Mitigation: Generate PowerShell alternatives where possible

## Deliverables

1. **Enhanced shell2batch converter** with Makefile support
2. **Comprehensive documentation** including examples
3. **Test suite** covering all new features
4. **Example conversions** for common use cases

This plan provides a structured approach to extending shell2batch into a comprehensive cross-platform build script conversion tool.