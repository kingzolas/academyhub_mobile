#!/usr/bin/env bash
set -euo pipefail

# This is the only production web build entry point. It deliberately removes
# the prior generated directory so a Netlify publish can never reuse a stale
# build/web artifact from a previous command.
readonly APP_NAME="${APP_NAME:-academyhub-mobile-web}"
readonly BUILD_DIR="build/web"
readonly DEPLOYED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
readonly FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.1}"
readonly DEFAULT_FLUTTER_VERSION='3.41.1'
readonly DEFAULT_FLUTTER_SDK_URL='https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.1-stable.tar.xz'
readonly DEFAULT_FLUTTER_SDK_SHA256='68f51b1bb3728d3be5a756f23a38af1f776e05c0729dd3a91d3dcf2c20d78138'

if [[ "$FLUTTER_VERSION" == "$DEFAULT_FLUTTER_VERSION" ]]; then
  readonly FLUTTER_SDK_URL="${FLUTTER_SDK_URL:-$DEFAULT_FLUTTER_SDK_URL}"
  readonly FLUTTER_SDK_SHA256="${FLUTTER_SDK_SHA256:-$DEFAULT_FLUTTER_SDK_SHA256}"
else
  # An explicit version override remains reproducible only with its official
  # archive URL and checksum supplied together by the caller.
  readonly FLUTTER_SDK_URL="${FLUTTER_SDK_URL:-}"
  readonly FLUTTER_SDK_SHA256="${FLUTTER_SDK_SHA256:-}"
fi

git_commit() {
  git rev-parse HEAD 2>/dev/null || printf 'nogit'
}

require_safe_value() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" || ! "$value" =~ ^[A-Za-z0-9._:-]+$ ]]; then
    echo "[BuildWeb] invalid or missing ${name}" >&2
    exit 1
  fi
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "[BuildWeb] prerequisite missing: ${command_name}" >&2
    exit 1
  fi
}

flutter_version_is_expected() {
  local version_output escaped_version
  escaped_version="${FLUTTER_VERSION//./\\.}"
  version_output="$(flutter --version 2>&1)" || return 1
  printf '%s\n' "$version_output" | grep -Eq "Flutter ${escaped_version}([^0-9.]|$)"
}

validate_flutter_version() {
  local version_output escaped_version
  escaped_version="${FLUTTER_VERSION//./\\.}"
  version_output="$(flutter --version 2>&1)" || {
    echo '[BuildWeb] unable to execute flutter --version' >&2
    exit 1
  }
  if ! printf '%s\n' "$version_output" | grep -Eq "Flutter ${escaped_version}([^0-9.]|$)"; then
    echo "[BuildWeb] Flutter ${FLUTTER_VERSION} is required, but a different version was found:" >&2
    printf '%s\n' "$version_output" >&2
    exit 1
  fi
  echo '[BuildWeb] Flutter SDK validado'
  printf '[BuildWeb] %s\n' "$(printf '%s\n' "$version_output" | head -n 1)"
}

install_flutter_for_netlify() {
  local cache_root sdk_dir archive_file temporary_dir sdk_parent

  for command_name in curl tar xz git sha256sum mktemp; do
    require_command "$command_name"
  done
  if [[ -z "$FLUTTER_SDK_URL" || -z "$FLUTTER_SDK_SHA256" ]]; then
    echo "[BuildWeb] Flutter ${FLUTTER_VERSION} override requires FLUTTER_SDK_URL and FLUTTER_SDK_SHA256" >&2
    exit 1
  fi

  # NETLIFY_CACHE_DIR is Netlify's documented build-cache location when it is
  # exposed. A normal XDG/HOME cache remains a safe, self-contained fallback.
  cache_root="${NETLIFY_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}}/academyhub-mobile/flutter"
  sdk_dir="${cache_root}/${FLUTTER_VERSION}"
  sdk_parent="$(dirname "$sdk_dir")"
  mkdir -p "$sdk_parent"

  if [[ -x "$sdk_dir/flutter/bin/flutter" ]]; then
    git config --global --add safe.directory "$sdk_dir/flutter" || true
    export PATH="$sdk_dir/flutter/bin:$PATH"
    if flutter_version_is_expected; then
      echo "[BuildWeb] Flutter ${FLUTTER_VERSION} found in cache"
      return
    fi
    echo "[BuildWeb] Ignoring incomplete or incompatible Flutter cache: $sdk_dir"
    rm -rf -- "$sdk_dir"
  fi

  echo "[BuildWeb] Instalando Flutter ${FLUTTER_VERSION}"
  temporary_dir="$(mktemp -d "${sdk_parent}/flutter-${FLUTTER_VERSION}.tmp.XXXXXX")"
  archive_file="${temporary_dir}/flutter.tar.xz"

  curl --fail --location --retry 3 --retry-delay 2 --output "$archive_file" "$FLUTTER_SDK_URL"
  if [[ ! -s "$archive_file" ]]; then
    echo '[BuildWeb] Flutter SDK download is empty or incomplete' >&2
    exit 1
  fi
  printf '%s  %s\n' "$FLUTTER_SDK_SHA256" "$archive_file" | sha256sum --check --status || {
    echo '[BuildWeb] Flutter SDK checksum validation failed' >&2
    exit 1
  }
  tar -xJf "$archive_file" -C "$temporary_dir"
  if [[ ! -x "$temporary_dir/flutter/bin/flutter" ]]; then
    echo '[BuildWeb] Flutter SDK archive is incomplete: flutter/bin/flutter is missing' >&2
    exit 1
  fi

  rm -rf -- "$sdk_dir"
  mv "$temporary_dir/flutter" "$sdk_dir"
  rm -rf -- "$temporary_dir"
  git config --global --add safe.directory "$sdk_dir/flutter" || true
  export PATH="$sdk_dir/flutter/bin:$PATH"
  validate_flutter_version
}

ensure_flutter() {
  local host_os
  host_os="$(uname -s)"
  if command -v flutter >/dev/null 2>&1 && flutter_version_is_expected; then
    validate_flutter_version
    return
  fi

  if [[ "${NETLIFY:-false}" == 'true' && "$host_os" == 'Linux' ]]; then
    install_flutter_for_netlify
    validate_flutter_version
    return
  fi

  if command -v flutter >/dev/null 2>&1; then
    echo "[BuildWeb] Flutter ${FLUTTER_VERSION} is required; the Flutter on PATH is incompatible." >&2
    flutter --version >&2 || true
  elif [[ "$host_os" != 'Linux' ]]; then
    echo "[BuildWeb] Flutter ${FLUTTER_VERSION} must be installed on PATH for local non-Linux builds. The script will not download the Linux SDK here." >&2
  else
    echo "[BuildWeb] Flutter ${FLUTTER_VERSION} is not available. Automatic SDK installation is restricted to Netlify Linux builds." >&2
  fi
  exit 1
}

APP_VERSION_LINE="$(awk '/^version:/ { print $2; exit }' pubspec.yaml)"
if [[ -z "$APP_VERSION_LINE" ]]; then
  echo '[BuildWeb] pubspec.yaml does not declare version' >&2
  exit 1
fi
readonly APP_VERSION="${APP_VERSION_LINE%%+*}"
readonly APP_BUILD_NUMBER="${APP_VERSION_LINE#*+}"
readonly COMMIT_REF="${COMMIT_REF:-$(git_commit)}"

if [[ "${NETLIFY:-false}" == "true" ]]; then
  # Netlify provides these values for a real deploy. Do not fall back to a
  # local identifier there: a production build must remain traceable.
  require_safe_value 'DEPLOY_ID' "${DEPLOY_ID:-}"
  require_safe_value 'COMMIT_REF' "$COMMIT_REF"
  require_safe_value 'BUILD_ID' "${BUILD_ID:-}"
  readonly BUILD_IDENTIFIER="netlify-${DEPLOY_ID}-${COMMIT_REF}"
  readonly PIPELINE_BUILD_NUMBER="$BUILD_ID"
  readonly BUILD_CONTEXT="${CONTEXT:-production}"
else
  require_safe_value 'local commit reference' "$COMMIT_REF"
  local_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  readonly BUILD_IDENTIFIER="${APP_BUILD_ID:-local-${COMMIT_REF:0:12}-${local_timestamp}}"
  require_safe_value 'APP_BUILD_ID' "$BUILD_IDENTIFIER"
  readonly PIPELINE_BUILD_NUMBER="local-${local_timestamp}"
  readonly BUILD_CONTEXT='local'
fi

if [[ "$BUILD_IDENTIFIER" == *'dev-local'* ]]; then
  echo '[BuildWeb] dev-local is not a valid build identifier' >&2
  exit 1
fi

echo "[BuildWeb] app=${APP_NAME} version=${APP_VERSION}+${APP_BUILD_NUMBER}"
echo "[BuildWeb] buildId=${BUILD_IDENTIFIER} commit=${COMMIT_REF}"
echo "[BuildWeb] deployedAt=${DEPLOYED_AT} context=${BUILD_CONTEXT}"

require_command git
ensure_flutter
if [[ "${NETLIFY:-false}" == 'true' ]]; then
  flutter config --no-analytics
fi
echo '[BuildWeb] Executando flutter pub get'
flutter pub get

rm -rf -- "$BUILD_DIR"

echo '[BuildWeb] Executando flutter build web'
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=APP_BUILD_ID="${BUILD_IDENTIFIER}" \
  --dart-define=APP_NAME="${APP_NAME}" \
  --dart-define=APP_UPDATE_LOGS="${APP_UPDATE_LOGS:-false}" \
  --dart-define=APP_UPDATE_CHECK_SECONDS="${APP_UPDATE_CHECK_SECONDS:-300}"

test -f "$BUILD_DIR/index.html"
test -f "$BUILD_DIR/main.dart.js"
test -f "$BUILD_DIR/flutter_bootstrap.js"
test -f "$BUILD_DIR/flutter_service_worker.js"

cat > "$BUILD_DIR/version.json" <<EOF
{
  "app": "${APP_NAME}",
  "version": "${APP_VERSION}",
  "buildNumber": "${APP_BUILD_NUMBER}",
  "buildId": "${BUILD_IDENTIFIER}",
  "commit": "${COMMIT_REF}",
  "deployedAt": "${DEPLOYED_AT}",
  "context": "${BUILD_CONTEXT}",
  "pipelineBuildId": "${PIPELINE_BUILD_NUMBER}"
}
EOF

cp web/_headers "$BUILD_DIR/_headers"
cp web/_redirects "$BUILD_DIR/_redirects"
cp web/404.html "$BUILD_DIR/404.html"
cp web/flutter_service_worker.js "$BUILD_DIR/flutter_service_worker.js"

if [[ ! -s "$BUILD_DIR/flutter_service_worker.js" ]]; then
  echo '[BuildWeb] Flutter migration worker is empty' >&2
  exit 1
fi

if ! grep -Fq "$BUILD_IDENTIFIER" "$BUILD_DIR/main.dart.js"; then
  echo '[BuildWeb] APP_BUILD_ID was not embedded in main.dart.js' >&2
  exit 1
fi
if grep -R -Fq 'dev-local' "$BUILD_DIR"; then
  echo '[BuildWeb] generated artifact contains forbidden dev-local value' >&2
  exit 1
fi

echo '[BuildWeb] fresh publish directory is ready at build/web'
