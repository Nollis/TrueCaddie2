#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
course_studio="$repo_root/course-studio"
domain_package="$repo_root/ios/TrueCaddieDomain"

step() {
    printf '\n==> %s\n' "$1"
}

(
    cd "$course_studio"

    if [ ! -d node_modules ]; then
        step "Installing course-studio dependencies"
        npm install --silent
    fi

    step "Publishing pilot bundle"
    npm run --silent publish:pilot

    step "Validating published bundle against shared schema"
    npm run --silent validate:bundle
)

if command -v swift >/dev/null 2>&1; then
    (
        cd "$domain_package"
        step "Running Swift domain tests"
        swift test
    )
else
    printf '\n==> Skipping Swift domain tests (swift CLI not found on PATH)\n'
fi

printf '\nAll checks passed.\n'
