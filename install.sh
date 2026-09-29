#!/usr/bin/env bash
#
# install.sh — build and install the Swift version of Hebcal4Menubar.
#
# This is a mutating script, so it only PRINTS the commands it would run.
# Nothing changes until you pipe its output into a shell:
#
#   bash install.sh                  # preview: build + install
#   bash install.sh | bash           # run:     build + install
#   bash install.sh build_app        # preview the build only
#   bash install.sh install_app      # preview the install only (needs a build)
#   INSTALL_DIR=~/Applications bash install.sh | bash
#   CODESIGN_IDENTITY='Apple Development: …' bash install.sh | bash
#
# CODESIGN_IDENTITY (default: ad-hoc, "-") signs with a real certificate.
# macOS ties the Location Services permission to the signature; an ad-hoc
# signature changes with every build, so macOS may ask again after each
# install. A stable identity keeps the permission.
#
# The generator needs bash >= 4.2 (macOS /bin/bash is 3.2: `brew install bash`).
# The emitted commands are plain POSIX sh, so any shell can run them.
#
# If a check fails, the generator reports it on stderr and prints `exit 1` on
# stdout, so `| bash` fails too instead of running an empty stream. When you
# pipe into another consumer, use `set -o pipefail` as well.
#
# Sourceable: `source install.sh` defines the functions and runs nothing, so an
# orchestrator can compose them, for example:
#
#   source install.sh && preflight_check && queue_build && emit_commands | bash
#
# Values that the repository already defines are derived, never copied: the
# app and executable names and the icon come from Info.plist, and the source
# list is every Hebcal4Menubar/*.swift file.

# Detect sourcing in this file's own frame, before anything else.
(return 0 2>/dev/null) && is_sourced='true' || is_sourced='false'

# Minimum bash version. This block must stay bash 3.2 compatible.
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2) )); then
    printf 'install.sh: needs bash >= 4.2, this is %s. Install it: brew install bash\n' \
        "$BASH_VERSION" >&2
    if [[ "$is_sourced" = 'true' ]]; then
        return 1
    fi
    printf 'exit 1\n'    # make `bash install.sh | bash` fail as well
    exit 1
fi

###############################################################################
# Settings (derived from the repository layout; INSTALL_DIR may override)
###############################################################################

script_dir=${BASH_SOURCE[0]%/*}
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir=.
repo_root=$(cd "$script_dir" && pwd -P)
src_dir="$repo_root/Hebcal4Menubar"
build_dir="$repo_root/build"
info_plist="$src_dir/Info.plist"
install_dir="${INSTALL_DIR:-/Applications}"
sign_identity="${CODESIGN_IDENTITY:--}"

# The emitted stream starts with `cd "$repo_root"`, so build commands can use
# these short, readable repo-relative paths.
src_rel='Hebcal4Menubar'
build_rel='build'


# Filled in by preflight_check.
app_name=''
exe_name=''
icon_file=''
sources=()

# Commands queued by the queue_* functions and printed by emit_commands.
steps=()
build_queued='false'
cli_args=''

###############################################################################
# Harness
###############################################################################

# end_function <rc> <message>: log the outcome of the calling function. On
# failure, return when sourced (the caller decides) and exit when run
# directly — after printing `exit <rc>` so a piped shell fails too.
end_function() {
    local rc="$1"; shift
    if [[ "$rc" -eq 0 ]]; then
        printf '[%(%F %T)T] INFO (%s): %s\n' -1 "${FUNCNAME[1]}" "$*" >&2
        return 0
    fi
    printf '[%(%F %T)T] ERROR (%s): %s\n' -1 "${FUNCNAME[1]}" "$*" >&2
    if [[ "$is_sourced" = 'true' ]]; then
        return "$rc"
    fi
    printf 'exit %d\n' "$rc"
    exit "$rc"
}

# step <command> [args...]: queue one command, each word shell-quoted.
step() {
    local line
    printf -v line '%q ' "$@"
    steps+=("${line% }")
}

# step_raw <text>: queue a command line that is already correctly quoted.
step_raw() {
    steps+=("$1")
}

###############################################################################
# Checks (read-only, run directly)
###############################################################################

require_tools() {
    local tool missing=()
    for tool in "$@"; do
        type -P "$tool" >/dev/null || missing+=("$tool")
    done
    if (( ${#missing[@]} )); then
        end_function 127 "missing tools: ${missing[*]} (Xcode command-line tools: xcode-select --install)"
        return
    fi
    end_function 0 "tools found: $*"
}

read_plist_key() {
    plutil -extract "$1" raw -o - "$info_plist" 2>/dev/null
}

preflight_check() {
    # $OSTYPE, not `uname`: no external tool whose absence could make this
    # check report the wrong cause.
    if [[ "$OSTYPE" != darwin* ]]; then
        end_function 1 "this app builds only on macOS (OSTYPE=$OSTYPE)"
        return
    fi
    require_tools swiftc codesign ditto plutil pgrep pkill open || return

    if [[ ! -f "$info_plist" ]]; then
        end_function 1 "Info.plist not found: $info_plist"
        return
    fi
    app_name=$(read_plist_key CFBundleName)
    exe_name=$(read_plist_key CFBundleExecutable)
    icon_file=$(read_plist_key CFBundleIconFile)
    if [[ -z "$app_name" || -z "$exe_name" ]]; then
        end_function 1 "CFBundleName or CFBundleExecutable missing in $info_plist"
        return
    fi
    [[ -n "$icon_file" && "$icon_file" != *.icns ]] && icon_file+='.icns'
    if [[ -n "$icon_file" && ! -f "$src_dir/$icon_file" ]]; then
        end_function 1 "icon $icon_file (CFBundleIconFile) not found in $src_dir"
        return
    fi

    local nullglob_was
    nullglob_was=$(shopt -p nullglob)
    shopt -s nullglob
    sources=("$src_dir"/*.swift)
    eval "$nullglob_was"
    if (( ${#sources[@]} == 0 )); then
        end_function 1 "no Swift sources in $src_dir"
        return
    fi

    if [[ "$sign_identity" != '-' ]]; then
        require_tools security || return
        if ! security find-identity -v -p codesigning | grep -qF -- "$sign_identity"; then
            end_function 1 "signing identity not found in the keychain: $sign_identity (list: security find-identity -v -p codesigning)"
            return
        fi
    fi

    if [[ ! -d "$install_dir" || ! -w "$install_dir" ]]; then
        end_function 1 "install directory missing or not writable: $install_dir"
        return
    fi
    end_function 0 "$app_name: ${#sources[@]} sources, install to $install_dir"
}

###############################################################################
# Actions (queue commands; nothing runs here)
###############################################################################

queue_build() {
    local app="$build_rel/$app_name.app"
    step cd "$repo_root"
    step_raw "echo '==> Compiling ${#sources[@]} Swift files'"
    step mkdir -p "$build_rel"
    step swiftc -O "${sources[@]#"$repo_root/"}" -o "$build_rel/$exe_name"
    step_raw "echo '==> Assembling $app_name.app'"
    # build/ is git-ignored build output; start from an empty bundle so no
    # stale file from an older build survives.
    step rm -rf "$app"
    step mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    step cp "$build_rel/$exe_name" "$app/Contents/MacOS/$exe_name"
    step cp "$src_rel/Info.plist" "$app/Contents/Info.plist"
    if [[ -n "$icon_file" ]]; then
        step cp "$src_rel/$icon_file" "$app/Contents/Resources/$icon_file"
    fi
    # The menubar PNGs are full-color, not template images (ICON_NOTES.md),
    # so they are deliberately not copied.
    if [[ "$sign_identity" == '-' ]]; then
        step_raw "echo '==> Signing (ad-hoc; macOS may ask for Location Services again)'"
    else
        step_raw "echo '==> Signing with the given identity'"
    fi
    step codesign --sign "$sign_identity" --force "$app"
    step codesign --verify "$app"
    build_queued='true'
    end_function 0 "queued build of $repo_root/$app"
}

queue_install() {
    local built="$build_dir/$app_name.app"
    local target="$install_dir/$app_name.app"
    local trash q_exe q_target
    if [[ "$build_queued" != 'true' && ! -d "$built" ]]; then
        end_function 1 "no build at $built; run the build first: bash install.sh | bash"
        return
    fi
    printf -v trash '%s/.Trash/%s-%(%Y%m%d-%H%M%S)T.app' "$HOME" "$app_name" -1
    printf -v q_exe '%q' "$exe_name"
    printf -v q_target '%q' "$target"

    # queue_build already changed to the repository; install_app alone has not.
    [[ "$build_queued" == 'true' ]] || step cd "$repo_root"
    step_raw "echo '==> Installing to $target'"
    # Both branches are explicit, so a failure inside a branch still stops
    # the chain, and "not running" / "no old copy" are reported, not hidden.
    step_raw "if pgrep -x $q_exe >/dev/null; then echo '    quitting the running app'; pkill -x $q_exe && sleep 1; else echo '    app not running'; fi"
    step_raw "if [ -e $q_target ]; then echo '    moving the old copy to the Trash'; mv $q_target $(printf '%q' "$trash"); else echo '    no old copy'; fi"
    step ditto "$build_rel/$app_name.app" "$target"
    step_raw "echo '==> Launching $app_name'"
    step open "$target"
    end_function 0 "queued install of $built to $target"
}

# Print the queued commands as one &&-chained stream. If a step fails, the
# steps after it do not run, and the stream says how to resume.
emit_commands() {
    if (( ${#steps[@]} == 0 )); then
        end_function 1 'nothing queued'
        return
    fi
    local i last=$(( ${#steps[@]} - 1 ))
    printf '# Generated by install.sh on %(%F %T)T. Review, then run: bash install.sh%s | bash\n' \
        -1 "${cli_args:+ $cli_args}"
    printf '{\n'
    for i in "${!steps[@]}"; do
        if (( i < last )); then
            printf '    %s &&\n' "${steps[i]}"
        else
            printf '    %s\n' "${steps[i]}"
        fi
    done
    printf '} || { echo "install.sh: a step failed (the last ==> line shows the stage); the steps after it did not run. Fix the cause, then run again: bash install.sh%s | bash" >&2; exit 1; }\n' \
        "${cli_args:+ $cli_args}"
    steps=()
    end_function 0 'commands emitted'
}

###############################################################################
# Pipelines
###############################################################################

build_and_install() {
    preflight_check && queue_build && queue_install && emit_commands
}

build_app() {
    preflight_check && queue_build && emit_commands
}

install_app() {
    preflight_check && queue_install && emit_commands
}

###############################################################################
# CLI Invocation
###############################################################################

# Ignore if sourced by another script.
if [[ "$is_sourced" = 'false' ]]; then
    cli_args="$*"
    if (( $# == 0 )); then
        build_and_install
    elif [[ "$1" =~ ^(build_and_install|build_app|install_app)$ ]]; then
        "$@"
    else
        printf 'usage: bash install.sh [build_and_install|build_app|install_app] [| bash]\n' >&2
        printf 'exit 2\n'
        exit 2
    fi
fi
