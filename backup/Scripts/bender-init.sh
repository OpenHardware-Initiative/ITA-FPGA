#!/usr/bin/env bash

# Copyright (c) 2019 ETH Zurich
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Author: Andreas Kurth <akurth@iis.ee.ethz.ch>

# This is just a little script that can be downloaded from the internet to
# install Bender.  It does platform detection, downloads the specified or the
# newest release package, and extracts it.
# Code and concept derived from the rustup installer.

set -u

readonly GITHUB_API_BENDER_ROOT='https://api.github.com/repos/pulp-platform/bender'
readonly GITHUB_API_HEADER='Accept: application/vnd.github.v3+json'

usage() {
    cat 1>&2 <<EOF
bender-init 0.2.0 (2020-11-06)
The installer for Bender

USAGE:
    bender-init [VERSION]

ARGUMENTS:
    VERSION     The Bender version to install.  Format MAJOR.MINOR.PATCH.  If
                not specified, use the latest stable release.
EOF
}

main() {
    if [ $# -lt 1 ]; then
        local _version="latest"
    else
        local _version="$1"
    fi

    downloader --check
    # need_cmd lsb_release
    need_cmd grep
    need_cmd mktemp
    need_cmd tar
    need_cmd rm

    get_architecture || err "Failed to determine target architecture!"
    local _arch="$RETVAL"

    if [ "$_arch" = "aarch64-apple-darwin" ] || [ "$_arch" = "x86_64-apple-darwin" ]; then
        local _arch="universal-apple-darwin"
    fi

    if [ "$_arch" = "aarch64-linux-gnu" ]; then
        local _arch="arm64-linux-gnu"
    fi

    if [ "$_arch" != "x86_64-linux-gnu" ] && [ "$_arch" != "universal-apple-darwin" ] && [ "$_arch" != "arm64-linux-gnu" ] ; then
        echo "Error: Architecture '$_arch' currently not supported!"
        return 1
    fi

    if [ "$_arch" = "x86_64-linux-gnu" ] || [ "$_arch" = "arm64-linux-gnu" ]; then
        get_distribution || err "Failed to determine distribution!"
        local _dist="$RETVAL"
        assert_nz "$_dist" "dist"

        local _platform="$_arch-$_dist"
    else
        local _platform="$_arch"
    fi

    get_asset_url "$_version" "$_platform" #|| err "Failed to get URL of release tar file!"
    local _asset_url="$RETVAL"
    assert_nz "$_asset_url" "asset_url"

    # Download and extract tar file in temporary directory.
    local _tmpdir="$(mktemp -d)"
    assert_nz "$_tmpdir" "mktemp"
    cd "$_tmpdir"
    downloader "$_asset_url" "bender.tar.gz" || err "Failed to download '$_asset_url'!"
    tar xf "bender.tar.gz" || err "Failed to extract tar file!"
    # Move executable to destination.
    cd - >/dev/null
    mv "$_tmpdir/bender" . || err "Failed to move executable to target directory!"
    # Remove temporary directory.
    rm -rf "$_tmpdir" || echo "Warning: Failed to clean up temporary directory."

    echo "Successfully installed $(./bender -V) in '$(pwd)'."
}

get_bitness() {
    need_cmd head
    # Architecture detection without dependencies beyond coreutils.
    # ELF files start out "\x7fELF", and the following byte is
    #   0x01 for 32-bit and
    #   0x02 for 64-bit.
    # The printf builtin on some shells like dash only supports octal
    # escape sequences, so we use those.
    local _current_exe_head
    _current_exe_head=$(head -c 5 /proc/self/exe )
    if [ "$_current_exe_head" = "$(printf '\177ELF\001')" ]; then
        echo 32
    elif [ "$_current_exe_head" = "$(printf '\177ELF\002')" ]; then
        echo 64
    else
        err "unknown platform bitness"
    fi
}

get_endianness() {
    local cputype=$1
    local suffix_eb=$2
    local suffix_el=$3

    # detect endianness without od/hexdump, like get_bitness() does.
    need_cmd head
    need_cmd tail

    local _current_exe_endianness
    _current_exe_endianness="$(head -c 6 /proc/self/exe | tail -c 1)"
    if [ "$_current_exe_endianness" = "$(printf '\001')" ]; then
        echo "${cputype}${suffix_el}"
    elif [ "$_current_exe_endianness" = "$(printf '\002')" ]; then
        echo "${cputype}${suffix_eb}"
    else
        err "unknown platform endianness"
    fi
}

get_architecture() {
    local _ostype _cputype _bitness _arch
    _ostype="$(uname -s)"
    _cputype="$(uname -m)"

    if [ "$_ostype" = Linux ]; then
        if [ "$(uname -o)" = Android ]; then
            _ostype=Android
        fi
    fi

    if [ "$_ostype" = Darwin ] && [ "$_cputype" = i386 ]; then
        # Darwin `uname -m` lies
        if sysctl hw.optional.x86_64 | grep -q ': 1'; then
            _cputype=x86_64
        fi
    fi

    case "$_ostype" in

        Android)
            _ostype=linux-android
            ;;

        Linux)
            _ostype=linux-gnu
            _bitness=$(get_bitness)
            ;;

        FreeBSD)
            _ostype=freebsd
            ;;

        NetBSD)
            _ostype=netbsd
            ;;

        DragonFly)
            _ostype=dragonfly
            ;;

        Darwin)
            _ostype=apple-darwin
            ;;

        MINGW* | MSYS* | CYGWIN*)
            _ostype=pc-windows-gnu
            ;;

        *)
            err "unrecognized OS type: $_ostype"
            ;;

    esac

    case "$_cputype" in

        i386 | i486 | i686 | i786 | x86)
            _cputype=i686
            ;;

        xscale | arm)
            _cputype=arm
            if [ "$_ostype" = "linux-android" ]; then
                _ostype=linux-androideabi
            fi
            ;;

        armv6l)
            _cputype=arm
            if [ "$_ostype" = "linux-android" ]; then
                _ostype=linux-androideabi
            else
                _ostype="${_ostype}eabihf"
            fi
            ;;

        armv7l | armv8l)
            _cputype=armv7
            if [ "$_ostype" = "linux-android" ]; then
                _ostype=linux-androideabi
            else
                _ostype="${_ostype}eabihf"
            fi
            ;;

        aarch64)
            _cputype=aarch64
            ;;

        arm64)
            _cputype=aarch64
            ;;

        x86_64 | x86-64 | x64 | amd64)
            _cputype=x86_64
            ;;

        mips)
            _cputype=$(get_endianness mips '' el)
            ;;

        mips64)
            if [ "$_bitness" -eq 64 ]; then
                # only n64 ABI is supported for now
                _ostype="${_ostype}abi64"
                _cputype=$(get_endianness mips64 '' el)
            fi
            ;;

        ppc)
            _cputype=powerpc
            ;;

        ppc64)
            _cputype=powerpc64
            ;;

        ppc64le)
            _cputype=powerpc64le
            ;;

        s390x)
            _cputype=s390x
            ;;

        *)
            err "unknown CPU type: $_cputype"

    esac

    # Detect 64-bit linux with 32-bit userland
    if [ "${_ostype}" = linux-gnu ] && [ "${_bitness}" -eq 32 ]; then
        case $_cputype in
            x86_64)
                _cputype=i686
                ;;
            mips64)
                _cputype=$(get_endianness mips '' el)
                ;;
            powerpc64)
                _cputype=powerpc
                ;;
        esac
    fi

    # Detect armv7 but without the CPU features Rust needs in that build,
    # and fall back to arm.
    # See https://github.com/rust-lang/rustup.rs/issues/587.
    if [ "$_ostype" = "linux-gnueabihf" ] && [ "$_cputype" = armv7 ]; then
        if ensure grep '^Features' /proc/cpuinfo | grep -q -v neon; then
            # At least one processor does not have NEON.
            _cputype=arm
        fi
    fi

    _arch="${_cputype}-${_ostype}"

    RETVAL="$_arch"
}

get_distribution() {
    local _vendor=""
    local _release=""
    if check_cmd lsb_release; then
        _vendor=$(lsb_release -i | cut -f 2 | tr '[:upper:]' '[:lower:]')
        _release=$(lsb_release -r | cut -f 2)
    else
        _vendor=$(cat /etc/os-release | sed -n -e "s/^ID=\(.*\)$/\1/p" | sed "s/\"//g")
        _release=$(cat /etc/os-release | sed -n -e "s/^VERSION_ID=\(.*\)$/\1/p" | sed "s/\"//g")
    fi
    if [ "$_vendor" = "centos" ] && [ "$(echo "$_release" | cut -d. -f3)" -lt 1708 ]; then
        say "Warning: CentOS older than 7.4.1708 detected, falling back to the latter."
        _release="7.4.1708"
    fi
    if [ "$_vendor" = "redhatenterprise" ]; then
        _vendor="rhel"
    fi
    RETVAL="$_vendor$_release"
}

get_download_url() {
    local _suburl="$1"
    local _platform="$2"
    RETVAL="$(downloader "$GITHUB_API_BENDER_ROOT/releases/$_suburl" | \
        grep -Eo "    \"browser_download_url\": \".*?bender-.*-$_platform\.tar\.gz\"" | \
        grep -Eo "http.*?bender-.*-$_platform\.tar\.gz")"
}

get_asset_url() {
    local _version="$1"
    local _platform="$2"
    if [ $_version = "latest" ]; then
        local _url="latest"
    else
        local _url="tags/v$_version"
    fi
    get_download_url "$_url" "$_platform"
    if [ -z "$RETVAL" ]; then
        say "Warning: No release for platform '$_platform' version '$_version' found, using latest."
        get_download_url "latest" "$_platform"
    fi
    if [ -z "$RETVAL" ]; then
        case "$_platform" in
            x86_64-linux-gnu*)
                say "Warning: Latest release not available for platform '$_platform', falling back to 'x86_64-linux-gnu'."
                _fallback="x86_64-linux-gnu"
                ;;
            arm64-linux-gnu*)
                say "Warning: Latest release not available for platform '$_platform', falling back to 'arm64-linux-gnu'."
                _fallback="arm64-linux-gnu"
                ;;
             *)
                err "Error: Latest release not available for platform '$_platform'!"
                ;;
        esac
        get_download_url "latest" "$_fallback"
    fi
    assert_nz "$RETVAL" assets
}

say() {
    printf 'bender-init: %s\n' "$1"
}

err() {
    say "$1" >&2
    exit 1
}

need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

assert_nz() {
    if [ -z "$1" ]; then err "assert_nz $2"; fi
}

# Run a command that should never fail. If the command fails execution
# will immediately terminate with an error showing the failing
# command.
ensure() {
    if ! "$@"; then err "command failed: $*"; fi
}

# This is just for indicating that commands' results are being
# intentionally ignored. Usually, because it's being executed
# as part of error handling.
ignore() {
    "$@"
}

# This wraps curl or wget. Try curl first, if not installed,
# use wget instead.
downloader() {
    local _dld
    if check_cmd curl; then
        _dld=curl
    elif check_cmd wget; then
        _dld=wget
    else
        _dld='curl or wget' # to be used in error message of need_cmd
    fi

    if [ "$1" = --check ]; then
        need_cmd "$_dld"
    elif [ "$_dld" = curl ]; then
        #local _curl="curl -H '$GITHUB_API_HEADER'"
        local _curl="curl"
        if ! check_help_for curl --proto --tlsv1.2; then
            echo "Warning: Not forcing TLS v1.2, this is potentially less secure"
        else
            _curl="$_curl --proto =https --tlsv1.2"
        fi
        _curl="$_curl --silent --show-error --fail --location $1"
        if [ "$#" -ge 2 ]; then
            _curl="$_curl --output $2"
        fi
        $_curl 2>/dev/null
    elif [ "$_dld" = wget ]; then
        local _wget="wget -H '$GITHUB_API_HEADER'"
        if ! check_help_for wget --https-only --secure-protocol; then
            echo "Warning: Not forcing TLS v1.2, this is potentially less secure"
        else
            _wget="$_wget --https-only --secure-protocol=TLSv1_2"
        fi
        _wget="$_wget $1"
        if [ "$#" -ge 2 ]; then
            _wget="$_wget -O $2"
        fi
        $_wget 2>/dev/null
    else
        err "Unknown downloader"   # should not reach here
    fi
    return $?
}

check_help_for() {
    local _cmd
    local _arg
    local _ok
    _cmd="$1"
    _ok="y"
    shift

    if [ "$_cmd" = "curl" ]; then
        _cmd="$_cmd --help all"
    else
        _cmd="$_cmd --help"
    fi

    # If we're running on OS-X, older than 10.13, then we always
    # fail to find these options to force fallback
    if check_cmd sw_vers; then
        if [ "$(sw_vers -productVersion | cut -d. -f2)" -lt 13 ]; then
            # Older than 10.13
            echo "Warning: Detected OS X platform older than 10.13"
            _ok="n"
        fi
    fi

    for _arg in "$@"; do
        if ! $_cmd | grep -q -- "$_arg"; then
            _ok="n"
        fi
    done

    test "$_ok" = "y"
}

main "$@" || exit 1
