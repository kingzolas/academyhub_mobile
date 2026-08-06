#!/usr/bin/env bash
set -euo pipefail

# This is the only production web build entry point. It deliberately removes
# the prior generated directory so a Netlify publish can never reuse a stale
# build/web artifact from a previous command.
readonly APP_NAME="${APP_NAME:-academyhub-mobile-web}"
readonly BUILD_DIR="build/web"
readonly DEPLOYED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

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

rm -rf -- "$BUILD_DIR"

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
