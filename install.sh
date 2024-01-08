#!/bin/sh
set -eu

# An installation script for Gleam on macOS and Linux
#   $ curl -fsSL https://gleam.pink/install.sh | sh

usage() {
  arg0="$0"
  if [ "$0" = sh ]; then
    arg0="curl -fsSL https://gleam.pink/install.sh | sh -s --"
  else
    not_curl_usage="The latest script is available at https://gleam.pink/install.sh
"
  fi

  cath <<EOF
Gleam installer

Installs a prebuilt Gleam binary by downloading one from GitHub.
Works on Linux and macOS for x86_64 and aarch64 architectures.

This script will cache downloaded assets, so you can use it to switch between versions.

${not_curl_usage-}
Usage:

  $arg0
        [--dry-run]
        [--version x.x.x | nightly]
        [--prefix <dir>]

  --dry-run
      Show the commands the installer would execute without running them.

  --version x.x.x | nightly
      Install a specific version instead of the latest.

  --prefix <dir>
      The installation prefix for Gleam. By default, this is /usr/local/gleam which will result in a binary placed at /usr/local/gleam/bin/gleam.

  --download
      Always download from Github, ignoring cached versions

  --binary-name <name>
      The name of the binary. By default, this is gleam. Can be useful with the --version option for giving different versions different names.

EOF
}

echo_latest_version() {
  version="$(curl -fsSLI -o /dev/null -w "%{url_effective}" https://github.com/gleam-lang/gleam/releases/latest)"
  version="${version#https://github.com/gleam-lang/gleam/releases/tag/v}"
  echo "$version"
}

echo_postinstall() {
  if [ "${DRY_RUN-}" ]; then
    echo_dryrun_postinstall
    return
  fi

  cath <<EOF

Gleam has been installed to

  $BINARY_LOCATION

EOF

  GLEAM_COMMAND="$(command -v "$BINARY_NAME" || true)"

  if [ -z "${GLEAM_COMMAND}" ]; then
    cath <<EOF
You'll need to extend your path to use Gleam

  $ PATH="$INSTALL_PREFIX/bin:\$PATH"

EOF
  elif [ "$GLEAM_COMMAND" != "$BINARY_LOCATION" ]; then
    echo_path_conflict "$GLEAM_COMMAND"
  else
    cath <<EOF
Try creating a new Gleam project!

  $ $BINARY_NAME new example
  $ cd example/

This will create a basic program that you can run

  $ $BINARY_NAME run

Gleam also has built-in support for testing

  $ $BINARY_NAME test

EOF
  fi
}

echo_dryrun_postinstall() {
  cath <<EOF

To install Gleam, re-run this script without the --dry-run flag.

EOF
}

echo_path_conflict() {
  cath <<EOF
There is another binary in your PATH that conflicts with the binary we've installed.

  $1

This is likely because of an existing installation of Gleam. See our documentation for suggestions on how to resolve this.

  https://github.com/gleam-community/gleam-install/blob/main/docs/PATH.md#path-conflicts

EOF
}

main() {
  if [ "${TRACE-}" ]; then
    set -x
  fi

  unset \
    DOWNLOAD \
    DRY_RUN \
    INSTALL_PREFIX \
    BINARY_NAME \
    VERSION

  while [ "$#" -gt 0 ]; do
    case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --download)
      DOWNLOAD=1
      ;;
    --prefix)
      INSTALL_PREFIX="$(parse_arg "$@")"
      shift
      ;;
    --prefix=*)
      INSTALL_PREFIX="$(parse_arg "$@")"
      ;;
    --version)
      VERSION="$(parse_arg "$@")"
      shift
      ;;
    --version=*)
      VERSION="$(parse_arg "$@")"
      ;;
    --binary-name)
      BINARY_NAME="$(parse_arg "$@")"
      shift
      ;;
    --binary-name=*)
      BINARY_NAME="$(parse_arg "$@")"
      ;;
    -h | --h | -help | --help)
      usage
      exit 0
      ;;
    -*)
      echoerr "Unknown flag $1"
      echoerr "Run with --help to see usage."
      exit 1
      ;;
    esac

    shift
  done

  # Secret environment variables; for testing!
  OS=${GLEAM_INSTALL_OS:-$(os)}
  ARCH=${GLEAM_INSTALL_ARCH:-$(arch)}
  LINKAGE=${GLEAM_INSTALL_LINKAGE:-$(linkage)}

  # Fill in defaults for these if the flags were not set
  INSTALL_PREFIX=${INSTALL_PREFIX:-/usr/local/gleam}
  BINARY_NAME=${BINARY_NAME:-gleam}

  CACHE_DIR=$(echo_cache_dir)
  VERSION=${VERSION:-$(echo_latest_version)}

  # Quit early if there won't be a binary availabe
  if [ ! has_prebuilt_binary ]; then
    echoerr "Sorry, but your system isn't currently supported!"
    exit 1
  fi

  if [ "${DRY_RUN-}" ]; then
    echoh "Running with --dry-run"
    echoh "Here are the commands that would be run to install Gleam:"
    echoh
  fi

  install_from_github
}

parse_arg() {
  case "$1" in
  *=*)
    # Remove everything after first equal sign.
    opt="${1%%=*}"
    # Remove everything before first equal sign.
    optarg="${1#*=}"
    if [ ! "$optarg" ]; then
      echoerr "$opt requires an argument"
      echoerr "Run with --help to see usage."
      exit 1
    fi
    echo "$optarg"
    return
    ;;
  esac

  case "${2-}" in
  "" | -*)
    echoerr "$1 requires an argument"
    echoerr "Run with --help to see usage."
    exit 1
    ;;
  *)
    echo "$2"
    return
    ;;
  esac
}

fetch() {
  URL="$1"
  FILE="$2"

  if [ -e "$FILE" ] && [ ! "${DOWNLOAD-}" ]; then
    echoh "+ Using version from cache: $FILE"
    return
  fi

  sh_c mkdir -p "$CACHE_DIR"
  sh_c curl \
    -#fsSL \
    -o "$FILE.incomplete" \
    -C - \
    "$URL"
  sh_c mv "$FILE.incomplete" "$FILE"
}

install_from_github() {
  unset DONOTCACHE
  if [ "${VERSION}" == "nightly" ]; then
    DOWNLOAD=1
    DONOTCACHE=1
  else
    VERSION="v$VERSION"
  fi

  echoh "Installing Gleam $VERSION from GitHub."
  echoh

  CACHED_TAR="$CACHE_DIR/gleam-${VERSION}-${ARCH}-${LINKAGE}.tar.gz"

  fetch "https://github.com/gleam-lang/gleam/releases/download/${VERSION}/gleam-${VERSION}-${ARCH}-${LINKAGE}.tar.gz" \
    "$CACHED_TAR"

  # -w only works if the directory exists so try creating it first. If this
  # fails we can ignore the error as the -w check will then swap us to sudo.
  sh="sh_c"
  sh_c mkdir -p "$INSTALL_PREFIX" 2>/dev/null || true
  if [ ! -w "$INSTALL_PREFIX" ]; then
    sh="sudo_sh_c"
  fi

  sh_c tar -C "$CACHE_DIR" -xzf "$CACHED_TAR"

  "$sh" mkdir -p "$INSTALL_PREFIX/bin"
  BINARY_LOCATION="$INSTALL_PREFIX/bin/$BINARY_NAME"
  # Remove the file if it already exists to avoid macOS security issues
  if [ -f "$BINARY_LOCATION" ]; then
    "$sh" rm "$BINARY_LOCATION"
  fi
  # Move the binary to the correct location.
  "$sh" mv "$CACHE_DIR/gleam" "$BINARY_LOCATION"

  # Remove the tarball from the cache if needed
  if [ "${DONOTCACHE-}" ]; then
    rm "$CACHED_TAR"
  fi

  echo_postinstall
}

# Determine if we have standalone releases on GitHub for the system's arch.
has_prebuilt_binary() {
  case $OS in
  darwin | linux)
    case $ARCH in
    amd64) return 0 ;;
    arm64) return 0 ;;
    esac
  ;;
  esac

  return 1
}

os() {
  uname="$(uname)"
  case $uname in
  Linux) echo "linux" ;;
  Darwin) echo "darwin" ;;
  FreeBSD) echo "freebsd" ;;
  *) echo "$uname" ;;
  esac
}

arch() {
  uname_m=$(uname -m)
  case $uname_m in
  amd64) echo "x86_64" ;;
  arm64) echo "aarch64" ;;
  *) echo "$uname_m" ;;
  esac
}

linkage() {
  case $OS in
  darwin) echo "apple-darwin" ;;
  linux) echo "unknown-linux-musl" ;;
  *) return 1 ;;
  esac
}

command_exists() {
  if [ ! "$1" ]; then return 1; fi
  command -v "$@" >/dev/null
}

sh_c() {
  echoh "+ $*"
  if [ ! "${DRY_RUN-}" ]; then
    sh -c "$*"
  fi
}

sudo_sh_c() {
  if [ "$(id -u)" = 0 ]; then
    sh_c "$@"
  elif command_exists sudo; then
    sh_c "sudo $*"
  elif command_exists doas; then
    sh_c "doas $*"
  elif command_exists su; then
    sh_c "su - -c '$*'"
  else
    echoh
    echoerr "This script needs to run the following command as root."
    echoerr "  $*"
    echoerr "Please install sudo, su, or doas."
    exit 1
  fi
}

echo_cache_dir() {
  if [ "${XDG_CACHE_HOME-}" ]; then
    echo "$XDG_CACHE_HOME/gleam"
  elif [ "${HOME-}" ]; then
    echo "$HOME/.cache/gleam"
  else
    echo "/tmp/gleam"
  fi
}

echoh() {
  echo "$@" | humanpath
}

cath() {
  humanpath
}

echoerr() {
  echoh "$@" >&2
}

# humanpath replaces all occurrences of " $HOME" with " ~"
# and all occurrences of '"$HOME' with the literal '"$HOME'.
humanpath() {
  sed "s# $HOME# ~#g; s#\"$HOME#\"\$HOME#g"
}

main "$@"
