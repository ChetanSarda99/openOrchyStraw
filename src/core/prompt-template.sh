#!/usr/bin/env bash
# prompt-template.sh — Template inheritance for agent prompts
# v0.3.0: #54 — reduce prompt duplication via base template + agent overlays
# v0.4.0: Jinja2-style conditionals, default values, template composition/mixins
#
# Agent prompts share identical sections (PROTECTED FILES, Git Safety, Auto-Cycle,
# shared context instructions). Maintaining these across 9+ prompts is error-prone.
# This module resolves template inheritance at runtime: a base template provides
# shared sections, and each agent's overlay provides role-specific content.
#
# Template syntax:
#   {{VAR_NAME}}              — replaced with variable value (set via orch_tpl_set)
#   {{VAR_NAME|default}}      — replaced with value, or "default" if unset (v0.4)
#   <!-- include: path.md --> — replaced with file contents (relative to template dir)
#   <!-- begin: BLOCK -->     — start of named block (overridable by overlay)
#   <!-- end: BLOCK -->       — end of named block
#   {% if VAR_NAME %}...{% endif %}            — conditional section (v0.4)
#   {% if VAR_NAME %}...{% else %}...{% endif %} — if/else (v0.4)
#   <!-- mixin: path.md -->   — include as a composable mixin (v0.4)
#
# Inheritance model:
#   base.md defines shared sections + named blocks
#   overlay.md can override blocks and set variables
#   orch_tpl_render merges base + overlay → final prompt
#
# Provides:
#   orch_tpl_init             — set template directory
#   orch_tpl_set              — set a variable for substitution
#   orch_tpl_set_from_file    — set a variable from file contents
#   orch_tpl_render           — merge base + overlay → stdout
#   orch_tpl_resolve_includes — resolve <!-- include: path --> directives
#   orch_tpl_validate         — check for unresolved placeholders
#   orch_tpl_list_vars        — list all {{VAR}} placeholders in a file
#   orch_tpl_stats            — print template stats (sections, vars, includes)
#   orch_tpl_resolve_conditionals — process {% if %}...{% endif %} blocks (v0.4)
#   orch_tpl_resolve_defaults — process {{VAR|default}} syntax (v0.4)
#   orch_tpl_add_mixin        — register a mixin template (v0.4)
#   orch_tpl_resolve_mixins   — resolve <!-- mixin: path --> directives (v0.4)

[[ -n "${_ORCH_PROMPT_TEMPLATE_LOADED:-}" ]] && return 0
_ORCH_PROMPT_TEMPLATE_LOADED=1

# ── State ──
declare -g _ORCH_TPL_DIR=""                 # template directory root
declare -g -A _ORCH_TPL_VARS=()            # "VAR_NAME" -> value
declare -g -A _ORCH_TPL_BLOCKS=()          # "BLOCK_NAME" -> content (from overlay)
declare -g _ORCH_TPL_MAX_INCLUDE_DEPTH=5   # prevent infinite include recursion
declare -g _ORCH_TPL_MAX_FILE_SIZE=102400   # 100KB max per included file
declare -g -A _ORCH_TPL_MIXINS=()          # v0.4: "mixin_name" -> file path

# ── Helpers ──

_orch_tpl_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "prompt-tpl" "$2"
    fi
}

_orch_tpl_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Resolve a path relative to template dir, rejecting traversal
_orch_tpl_safe_path() {
    local path="$1"
    local base_dir="${2:-$_ORCH_TPL_DIR}"

    if [[ -z "$base_dir" ]]; then
        _orch_tpl_log ERROR "Template directory not set — call orch_tpl_init first"
        return 1
    fi

    # Reject path traversal
    if [[ "$path" == *".."* ]]; then
        _orch_tpl_log ERROR "Path traversal rejected: $path"
        return 1
    fi

    local resolved
    resolved=$(cd "$base_dir" 2>/dev/null && realpath -m "$path" 2>/dev/null) || {
        _orch_tpl_log ERROR "Cannot resolve path: $path"
        return 1
    }

    # Ensure resolved path is under base_dir
    local resolved_base
    resolved_base=$(realpath -m "$base_dir" 2>/dev/null) || return 1
    if [[ "$resolved" != "$resolved_base"* ]]; then
        _orch_tpl_log ERROR "Path escapes template dir: $path"
        return 1
    fi

    printf '%s' "$resolved"
}

# ── Public API ──

# orch_tpl_init <template_dir>
#   Set the template directory root. All includes and base/overlay paths
#   are resolved relative to this directory.
orch_tpl_init() {
    local dir="${1:?orch_tpl_init: template_dir required}"

    if [[ ! -d "$dir" ]]; then
        _orch_tpl_log ERROR "Template directory not found: $dir"
        return 1
    fi

    _ORCH_TPL_DIR="$dir"
    _ORCH_TPL_VARS=()
    _ORCH_TPL_BLOCKS=()
    _orch_tpl_log INFO "Template engine initialized (dir=$dir)"
}

# orch_tpl_set <var_name> <value>
#   Set a template variable for {{VAR_NAME}} substitution.
orch_tpl_set() {
    local name="${1:?orch_tpl_set: var_name required}"
    local value="${2:-}"

    # Validate variable name: alphanumeric + underscore only
    if [[ ! "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        _orch_tpl_log ERROR "Invalid variable name: $name (must be [A-Za-z_][A-Za-z0-9_]*)"
        return 1
    fi

    _ORCH_TPL_VARS["$name"]="$value"
}

# orch_tpl_set_from_file <var_name> <file_path>
#   Set a template variable from file contents.
orch_tpl_set_from_file() {
    local name="${1:?orch_tpl_set_from_file: var_name required}"
    local file_path="${2:?orch_tpl_set_from_file: file_path required}"

    if [[ ! -f "$file_path" ]]; then
        _orch_tpl_log ERROR "File not found for variable $name: $file_path"
        return 1
    fi

    local size
    size=$(wc -c < "$file_path")
    if [[ "$size" -gt "$_ORCH_TPL_MAX_FILE_SIZE" ]]; then
        _orch_tpl_log ERROR "File too large for variable $name: $file_path ($size bytes > $_ORCH_TPL_MAX_FILE_SIZE)"
        return 1
    fi

    local value
    value=$(cat "$file_path") || {
        _orch_tpl_log ERROR "Failed to read file for variable $name: $file_path"
        return 1
    }

    orch_tpl_set "$name" "$value"
}

# orch_tpl_resolve_includes <text> [depth]
#   Replace <!-- include: path.md --> directives with file contents.
#   Recursive up to MAX_INCLUDE_DEPTH.
orch_tpl_resolve_includes() {
    local text="${1:-}"
    local depth="${2:-0}"

    if [[ "$depth" -ge "$_ORCH_TPL_MAX_INCLUDE_DEPTH" ]]; then
        _orch_tpl_log WARN "Max include depth ($depth) reached — stopping recursion"
        printf '%s' "$text"
        return 0
    fi

    local result=""
    local found_include=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*\<!--[[:space:]]*include:[[:space:]]*(.*[^[:space:]])[[:space:]]*--\>[[:space:]]*$ ]]; then
            local include_path
            include_path=$(_orch_tpl_trim "${BASH_REMATCH[1]}")
            found_include=true

            local resolved_path
            resolved_path=$(_orch_tpl_safe_path "$include_path") || {
                result+="<!-- ERROR: cannot resolve include: $include_path -->"$'\n'
                continue
            }

            if [[ ! -f "$resolved_path" ]]; then
                _orch_tpl_log WARN "Include file not found: $include_path"
                result+="<!-- ERROR: file not found: $include_path -->"$'\n'
                continue
            fi

            local size
            size=$(wc -c < "$resolved_path")
            if [[ "$size" -gt "$_ORCH_TPL_MAX_FILE_SIZE" ]]; then
                _orch_tpl_log ERROR "Include file too large: $include_path ($size bytes)"
                result+="<!-- ERROR: file too large: $include_path -->"$'\n'
                continue
            fi

            local included
            included=$(cat "$resolved_path") || {
                result+="<!-- ERROR: cannot read: $include_path -->"$'\n'
                continue
            }

            result+="$included"$'\n'
        else
            result+="$line"$'\n'
        fi
    done <<< "$text"

    # Recurse if we found any includes (nested includes)
    if [[ "$found_include" == true ]]; then
        result=$(orch_tpl_resolve_includes "$result" $((depth + 1)))
    fi

    printf '%s' "$result"
}

# _orch_tpl_parse_overlay_blocks <overlay_text>
#   Extract named blocks from overlay and store in _ORCH_TPL_BLOCKS.
_orch_tpl_parse_overlay_blocks() {
    local text="$1"
    local in_block=false
    local block_name=""
    local block_content=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*\<!--[[:space:]]*begin:[[:space:]]*(.*[^[:space:]])[[:space:]]*--\>[[:space:]]*$ ]]; then
            if [[ "$in_block" == true ]]; then
                # Save previous block before starting new one
                _ORCH_TPL_BLOCKS["$block_name"]="$block_content"
            fi
            block_name=$(_orch_tpl_trim "${BASH_REMATCH[1]}")
            block_content=""
            in_block=true
        elif [[ "$line" =~ ^[[:space:]]*\<!--[[:space:]]*end:[[:space:]]*(.*[^[:space:]])[[:space:]]*--\>[[:space:]]*$ ]]; then
            local end_name
            end_name=$(_orch_tpl_trim "${BASH_REMATCH[1]}")
            if [[ "$in_block" == true && "$end_name" == "$block_name" ]]; then
                _ORCH_TPL_BLOCKS["$block_name"]="$block_content"
                in_block=false
                block_name=""
                block_content=""
            fi
        elif [[ "$in_block" == true ]]; then
            block_content+="$line"$'\n'
        fi
    done <<< "$text"

    # Handle unclosed block
    if [[ "$in_block" == true && -n "$block_name" ]]; then
        _ORCH_TPL_BLOCKS["$block_name"]="$block_content"
        _orch_tpl_log WARN "Unclosed block: $block_name"
    fi
}

# _orch_tpl_apply_blocks <base_text>
#   Replace named blocks in base text with overlay block content.
#   If no overlay block exists for a base block, the base default is kept.
_orch_tpl_apply_blocks() {
    local text="$1"
    local result=""
    local in_block=false
    local block_name=""
    local block_default=""
    local has_override=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*\<!--[[:space:]]*begin:[[:space:]]*(.*[^[:space:]])[[:space:]]*--\>[[:space:]]*$ ]]; then
            block_name=$(_orch_tpl_trim "${BASH_REMATCH[1]}")
            in_block=true
            block_default=""
            if [[ -n "${_ORCH_TPL_BLOCKS[$block_name]+x}" ]]; then
                has_override=true
            else
                has_override=false
            fi
        elif [[ "$line" =~ ^[[:space:]]*\<!--[[:space:]]*end:[[:space:]]*(.*[^[:space:]])[[:space:]]*--\>[[:space:]]*$ ]]; then
            local end_name
            end_name=$(_orch_tpl_trim "${BASH_REMATCH[1]}")
            if [[ "$in_block" == true && "$end_name" == "$block_name" ]]; then
                if [[ "$has_override" == true ]]; then
                    result+="${_ORCH_TPL_BLOCKS[$block_name]}"
                else
                    result+="$block_default"
                fi
                in_block=false
                block_name=""
            else
                result+="$line"$'\n'
            fi
        elif [[ "$in_block" == true ]]; then
            block_default+="$line"$'\n'
        else
            result+="$line"$'\n'
        fi
    done <<< "$text"

    printf '%s' "$result"
}

# _orch_tpl_substitute_vars <text>
#   Replace {{VAR_NAME}} placeholders with values from _ORCH_TPL_VARS.
_orch_tpl_substitute_vars() {
    local text="$1"

    for var_name in "${!_ORCH_TPL_VARS[@]}"; do
        local placeholder="{{${var_name}}}"
        local value="${_ORCH_TPL_VARS[$var_name]}"
        # Use bash string replacement (safe, no sed injection)
        while [[ "$text" == *"$placeholder"* ]]; do
            text="${text//"$placeholder"/"$value"}"
        done
    done

    printf '%s' "$text"
}

# orch_tpl_render <base_file> [overlay_file]
#   Merge base template with optional overlay → stdout.
#   Processing order: parse overlay blocks → apply blocks → resolve includes → substitute vars.
orch_tpl_render() {
    local base_file="${1:?orch_tpl_render: base_file required}"
    local overlay_file="${2:-}"

    # Resolve base file path
    local base_path
    if [[ "$base_file" == /* ]]; then
        base_path="$base_file"
    else
        base_path=$(_orch_tpl_safe_path "$base_file") || return 1
    fi

    if [[ ! -f "$base_path" ]]; then
        _orch_tpl_log ERROR "Base template not found: $base_file"
        return 1
    fi

    local base_text
    base_text=$(cat "$base_path") || {
        _orch_tpl_log ERROR "Cannot read base template: $base_file"
        return 1
    }

    # Parse overlay blocks if overlay provided
    _ORCH_TPL_BLOCKS=()
    if [[ -n "$overlay_file" ]]; then
        local overlay_path
        if [[ "$overlay_file" == /* ]]; then
            overlay_path="$overlay_file"
        else
            overlay_path=$(_orch_tpl_safe_path "$overlay_file") || return 1
        fi

        if [[ ! -f "$overlay_path" ]]; then
            _orch_tpl_log ERROR "Overlay file not found: $overlay_file"
            return 1
        fi

        local overlay_text
        overlay_text=$(cat "$overlay_path") || {
            _orch_tpl_log ERROR "Cannot read overlay: $overlay_file"
            return 1
        }

        # Extract variable assignments from overlay (lines like: VAR_NAME=value)
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
                local vname="${BASH_REMATCH[1]}"
                local vvalue="${BASH_REMATCH[2]}"
                _ORCH_TPL_VARS["$vname"]="$vvalue"
            fi
        done <<< "$overlay_text"

        _orch_tpl_parse_overlay_blocks "$overlay_text"
    fi

    # Apply blocks (overlay overrides base defaults)
    local result
    result=$(_orch_tpl_apply_blocks "$base_text")

    # Resolve includes
    result=$(orch_tpl_resolve_includes "$result")

    # Substitute variables
    result=$(_orch_tpl_substitute_vars "$result")

    printf '%s' "$result"
}

# orch_tpl_validate <text>
#   Check for unresolved {{VAR}} placeholders. Returns 1 if any found, 0 if clean.
#   Prints unresolved variable names to stdout.
orch_tpl_validate() {
    local text="${1:?orch_tpl_validate: text required}"
    local found=0

    while [[ "$text" =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        printf 'UNRESOLVED: {{%s}}\n' "$var_name"
        found=1
        # Remove this occurrence to find the next
        text="${text/"{{${var_name}}"/}"
    done

    return "$found"
}

# orch_tpl_list_vars <file_path>
#   List all {{VAR}} placeholders in a template file. One per line, deduplicated.
orch_tpl_list_vars() {
    local file_path="${1:?orch_tpl_list_vars: file_path required}"

    if [[ ! -f "$file_path" ]]; then
        _orch_tpl_log ERROR "File not found: $file_path"
        return 1
    fi

    local text
    text=$(cat "$file_path") || return 1

    local -A seen=()
    while [[ "$text" =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        if [[ -z "${seen[$var_name]+x}" ]]; then
            printf '%s\n' "$var_name"
            seen["$var_name"]=1
        fi
        text="${text/"{{${var_name}}"/}"
    done
}

# orch_tpl_stats <base_file> [overlay_file]
#   Print template stats: block count, variable count, include count.
orch_tpl_stats() {
    local base_file="${1:?orch_tpl_stats: base_file required}"
    local overlay_file="${2:-}"

    local base_path
    if [[ "$base_file" == /* ]]; then
        base_path="$base_file"
    else
        base_path=$(_orch_tpl_safe_path "$base_file") || return 1
    fi

    if [[ ! -f "$base_path" ]]; then
        _orch_tpl_log ERROR "Base template not found: $base_file"
        return 1
    fi

    local base_text
    base_text=$(cat "$base_path") || return 1

    # Count blocks in base
    local block_count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*\<!--[[:space:]]*begin: ]]; then
            block_count=$((block_count + 1))
        fi
    done <<< "$base_text"

    # Count variables
    local var_count=0
    local temp_text="$base_text"
    local -A var_seen=()
    while [[ "$temp_text" =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
        local vn="${BASH_REMATCH[1]}"
        if [[ -z "${var_seen[$vn]+x}" ]]; then
            var_count=$((var_count + 1))
            var_seen["$vn"]=1
        fi
        temp_text="${temp_text/"{{${vn}}"/}"
    done

    # Count includes
    local include_count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*\<!--[[:space:]]*include: ]]; then
            include_count=$((include_count + 1))
        fi
    done <<< "$base_text"

    # Overlay stats
    local overlay_block_count=0
    if [[ -n "$overlay_file" ]]; then
        local overlay_path
        if [[ "$overlay_file" == /* ]]; then
            overlay_path="$overlay_file"
        else
            overlay_path=$(_orch_tpl_safe_path "$overlay_file") || return 1
        fi
        if [[ -f "$overlay_path" ]]; then
            local overlay_text
            overlay_text=$(cat "$overlay_path") || return 1
            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*\<!--[[:space:]]*begin: ]]; then
                    overlay_block_count=$((overlay_block_count + 1))
                fi
            done <<< "$overlay_text"
        fi
    fi

    local base_chars=${#base_text}
    local base_tokens=$(( (base_chars + 3) / 4 ))

    printf 'template stats for %s:\n' "$base_file"
    printf '  blocks:     %d (base) / %d (overlay overrides)\n' "$block_count" "$overlay_block_count"
    printf '  variables:  %d unique\n' "$var_count"
    printf '  includes:   %d\n' "$include_count"
    printf '  base size:  ~%d tokens (%d chars)\n' "$base_tokens" "$base_chars"
}

# ===========================================================================
# v0.4.0 — Jinja2-style Conditionals, Default Values, Template Composition
# ===========================================================================

# ---------------------------------------------------------------------------
# orch_tpl_resolve_defaults — process {{VAR|default_value}} syntax
#
# If VAR is set in _ORCH_TPL_VARS, use it. Otherwise use the default.
# Also handles plain {{VAR}} by leaving them for _orch_tpl_substitute_vars.
# ---------------------------------------------------------------------------
orch_tpl_resolve_defaults() {
    local text="$1"
    local result="$text"

    # Match {{VAR_NAME|default_value}} — pipe separates var from default
    while [[ "$result" =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\|([^}]*)\}\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local default_val="${BASH_REMATCH[2]}"
        local full_match="{{${var_name}|${default_val}}}"

        if [[ -n "${_ORCH_TPL_VARS[$var_name]+x}" ]]; then
            result="${result/"$full_match"/"${_ORCH_TPL_VARS[$var_name]}"}"
        else
            result="${result/"$full_match"/"$default_val"}"
        fi
    done

    printf '%s' "$result"
}

# ---------------------------------------------------------------------------
# orch_tpl_resolve_conditionals — process {% if VAR %}...{% endif %} blocks
#
# Supports:
#   {% if VAR_NAME %}content{% endif %}
#   {% if VAR_NAME %}content{% else %}alt_content{% endif %}
#   {% if !VAR_NAME %}content{% endif %}  (negation)
#
# A variable is "truthy" if it exists in _ORCH_TPL_VARS and is non-empty.
# ---------------------------------------------------------------------------
orch_tpl_resolve_conditionals() {
    local text="$1"
    local result=""
    local -a lines=()

    # Split text into lines
    while IFS= read -r line; do
        lines+=("$line")
    done <<< "$text"

    local i=0
    local n=${#lines[@]}

    while [[ $i -lt $n ]]; do
        local line="${lines[$i]}"

        # Check for {% if VAR %} or {% if !VAR %}
        if [[ "$line" =~ ^[[:space:]]*\{%[[:space:]]*if[[:space:]]+([\!]?)([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*%\}[[:space:]]*$ ]]; then
            local negate="${BASH_REMATCH[1]}"
            local cond_var="${BASH_REMATCH[2]}"
            local if_content=""
            local else_content=""
            local in_else=false
            local depth=1

            i=$((i + 1))
            while [[ $i -lt $n && $depth -gt 0 ]]; do
                local inner="${lines[$i]}"

                # Nested if
                if [[ "$inner" =~ ^[[:space:]]*\{%[[:space:]]*if[[:space:]] ]]; then
                    depth=$((depth + 1))
                fi

                # endif
                if [[ "$inner" =~ ^[[:space:]]*\{%[[:space:]]*endif[[:space:]]*%\}[[:space:]]*$ ]]; then
                    depth=$((depth - 1))
                    if [[ $depth -eq 0 ]]; then
                        i=$((i + 1))
                        break
                    fi
                fi

                # else (only at depth 1)
                if [[ $depth -eq 1 ]] && [[ "$inner" =~ ^[[:space:]]*\{%[[:space:]]*else[[:space:]]*%\}[[:space:]]*$ ]]; then
                    in_else=true
                    i=$((i + 1))
                    continue
                fi

                if [[ "$in_else" == "true" ]]; then
                    else_content+="$inner"$'\n'
                else
                    if_content+="$inner"$'\n'
                fi
                i=$((i + 1))
            done

            # Evaluate condition
            local var_val="${_ORCH_TPL_VARS[$cond_var]:-}"
            local is_truthy=false
            [[ -n "$var_val" ]] && is_truthy=true

            if [[ -n "$negate" ]]; then
                [[ "$is_truthy" == "true" ]] && is_truthy=false || is_truthy=true
            fi

            if [[ "$is_truthy" == "true" ]]; then
                result+="$if_content"
            else
                result+="$else_content"
            fi
        else
            result+="$line"$'\n'
            i=$((i + 1))
        fi
    done

    printf '%s' "$result"
}

# ---------------------------------------------------------------------------
# orch_tpl_add_mixin — register a named mixin template
# Args: $1 — mixin name, $2 — file path (relative to template dir or absolute)
# ---------------------------------------------------------------------------
orch_tpl_add_mixin() {
    local name="${1:?orch_tpl_add_mixin: name required}"
    local path="${2:?orch_tpl_add_mixin: path required}"

    if [[ "$path" != /* ]]; then
        local resolved
        resolved=$(_orch_tpl_safe_path "$path") || return 1
        path="$resolved"
    fi

    if [[ ! -f "$path" ]]; then
        _orch_tpl_log ERROR "Mixin file not found: $path"
        return 1
    fi

    _ORCH_TPL_MIXINS["$name"]="$path"
}

# ---------------------------------------------------------------------------
# orch_tpl_resolve_mixins — resolve <!-- mixin: name --> directives
#
# Unlike includes, mixins are referenced by registered name (not path).
# Mixins also get variable substitution applied to their content.
# ---------------------------------------------------------------------------
orch_tpl_resolve_mixins() {
    local text="$1"
    local result=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*\<!--[[:space:]]*mixin:[[:space:]]*(.*[^[:space:]])[[:space:]]*--\>[[:space:]]*$ ]]; then
            local mixin_name
            mixin_name=$(_orch_tpl_trim "${BASH_REMATCH[1]}")

            local mixin_path="${_ORCH_TPL_MIXINS[$mixin_name]:-}"
            if [[ -z "$mixin_path" ]]; then
                _orch_tpl_log WARN "Mixin not registered: $mixin_name"
                result+="<!-- ERROR: mixin not found: $mixin_name -->"$'\n'
                continue
            fi

            if [[ ! -f "$mixin_path" ]]; then
                result+="<!-- ERROR: mixin file missing: $mixin_name -->"$'\n'
                continue
            fi

            local mixin_content
            mixin_content=$(cat "$mixin_path") || {
                result+="<!-- ERROR: cannot read mixin: $mixin_name -->"$'\n'
                continue
            }

            # Apply variable substitution to mixin content
            mixin_content=$(_orch_tpl_substitute_vars "$mixin_content")
            result+="$mixin_content"$'\n'
        else
            result+="$line"$'\n'
        fi
    done <<< "$text"

    printf '%s' "$result"
}

# ---------------------------------------------------------------------------
# orch_tpl_render_v2 — enhanced render with v0.4 features
#
# Processing order:
#   1. Parse overlay blocks
#   2. Apply blocks (overlay overrides base defaults)
#   3. Resolve includes
#   4. Resolve mixins
#   5. Resolve conditionals
#   6. Resolve defaults ({{VAR|default}})
#   7. Substitute variables ({{VAR}})
# ---------------------------------------------------------------------------
orch_tpl_render_v2() {
    local base_file="${1:?orch_tpl_render_v2: base_file required}"
    local overlay_file="${2:-}"

    # Resolve base file path
    local base_path
    if [[ "$base_file" == /* ]]; then
        base_path="$base_file"
    else
        base_path=$(_orch_tpl_safe_path "$base_file") || return 1
    fi

    if [[ ! -f "$base_path" ]]; then
        _orch_tpl_log ERROR "Base template not found: $base_file"
        return 1
    fi

    local base_text
    base_text=$(cat "$base_path") || {
        _orch_tpl_log ERROR "Cannot read base template: $base_file"
        return 1
    }

    # Parse overlay blocks if overlay provided
    _ORCH_TPL_BLOCKS=()
    if [[ -n "$overlay_file" ]]; then
        local overlay_path
        if [[ "$overlay_file" == /* ]]; then
            overlay_path="$overlay_file"
        else
            overlay_path=$(_orch_tpl_safe_path "$overlay_file") || return 1
        fi

        if [[ ! -f "$overlay_path" ]]; then
            _orch_tpl_log ERROR "Overlay file not found: $overlay_file"
            return 1
        fi

        local overlay_text
        overlay_text=$(cat "$overlay_path") || {
            _orch_tpl_log ERROR "Cannot read overlay: $overlay_file"
            return 1
        }

        # Extract variable assignments from overlay
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
                _ORCH_TPL_VARS["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
            fi
        done <<< "$overlay_text"

        _orch_tpl_parse_overlay_blocks "$overlay_text"
    fi

    local result
    result=$(_orch_tpl_apply_blocks "$base_text")
    result=$(orch_tpl_resolve_includes "$result")
    result=$(orch_tpl_resolve_mixins "$result")
    result=$(orch_tpl_resolve_conditionals "$result")
    result=$(orch_tpl_resolve_defaults "$result")
    result=$(_orch_tpl_substitute_vars "$result")

    printf '%s' "$result"
}
