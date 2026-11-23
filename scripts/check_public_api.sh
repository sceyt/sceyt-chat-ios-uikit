#!/bin/bash

# Build the SceytChatUIKit module for iOS devices with library evolution and
# compare its public Swift interface with api/SceytChatUIKit.swiftinterface.
# Pass --update first to accept an intentional change. Other arguments are
# passed to xcodebuild, for example -clonedSourcePackagesDirPath SourcePackages.
# DerivedData goes to build/api/DerivedData unless DERIVED_DATA_PATH is set.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REFERENCE="${PROJECT_ROOT}/api/SceytChatUIKit.swiftinterface"
readonly REPORT_DIR="${PROJECT_ROOT}/build/api"
readonly GENERATED="${REPORT_DIR}/SceytChatUIKit.swiftinterface"
readonly LOG="${REPORT_DIR}/build.log"
readonly DERIVED_DATA="${DERIVED_DATA_PATH:-${REPORT_DIR}/DerivedData}"
readonly CONFIGURATION=Release
readonly INTERFACE="${DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphoneos/SceytChatUIKit.swiftmodule/arm64-apple-ios.swiftinterface"

update=NO
if [[ "${1:-}" == "--update" ]]; then
    update=YES
    shift
elif [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
    echo "Usage: $0 [--update] [xcodebuild arguments...]"
    exit 0
fi

mkdir -p "${REPORT_DIR}"
rm -f "${INTERFACE}"

# Library evolution makes the compiler emit the module's .swiftinterface. The
# check uses it only to read the API; Package.swift and the podspec do not
# enable library evolution for consumers.
# The emitted interface is not verified: it does not compile as printed, because
# Appearance.Images.galleryVidepAsset is printed with the internal type
# ImageAsset.Image (from its closure initializer) instead of UIImage.
echo "Building SceytChatUIKit with library evolution. Log: ${LOG#"${PROJECT_ROOT}/"}"
if ! xcodebuild build \
    -scheme SceytChatUIKit \
    -configuration "${CONFIGURATION}" \
    -destination generic/platform=iOS \
    -derivedDataPath "${DERIVED_DATA}" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    'OTHER_SWIFT_FLAGS=$(inherited) -no-verify-emitted-module-interface' \
    CODE_SIGNING_ALLOWED=NO \
    "$@" > "${LOG}" 2>&1; then
    grep -E "error:" "${LOG}" | sort -u | head -20 >&2 || true
    echo "The library evolution build failed. See ${LOG#"${PROJECT_ROOT}/"}." >&2
    exit 1
fi

if [[ ! -f "${INTERFACE}" ]]; then
    echo "The build did not emit ${INTERFACE}." >&2
    exit 1
fi

# Remove the differences in how Xcode versions print the same API, so the
# reference matches builds from Xcode 26 and 27:
# - compiler version and flag comments, and #if compiler(...) feature guards;
# - Swift 6.4 module selectors: Swift::Bool and
#   UIKit::UIView.UIKit::ContentMode become Swift.Bool and
#   UIKit.UIView.ContentMode, as earlier compilers print them;
# - generic arguments on property wrapper attributes (@Combine.Published<T>);
# - the order of platforms in @available.
perl -ne '
    next if m{^// swift-} || m{^\s*#(?:if|elseif|else|endif)\b};
    s/\.\w+::/./g;
    s/::/./g;
    s/\@(\w+(?:\.\w+)*)(<(?:[^<>]++|(?2))*>)/\@$1/g;
    s{\@available\(([^()]*)\)}{
        my @platforms = split /, /, $1;
        (grep { !/^(?:\w+ [\d.]+|\*)$/ } @platforms)
            ? "\@available(" . join(", ", @platforms) . ")"
            : "\@available(" . join(", ", (sort grep { $_ ne "*" } @platforms), (grep { $_ eq "*" } @platforms)) . ")"
    }ge;
    print;
' "${INTERFACE}" > "${GENERATED}"

if [[ "${update}" == "YES" ]]; then
    mkdir -p "$(dirname "${REFERENCE}")"
    cp "${GENERATED}" "${REFERENCE}"
    echo "Updated ${REFERENCE#"${PROJECT_ROOT}/"}. Review and commit the diff."
    exit 0
fi

if [[ ! -f "${REFERENCE}" ]]; then
    echo "Missing ${REFERENCE#"${PROJECT_ROOT}/"}. Run $0 --update to create it." >&2
    exit 1
fi

if ! diff -u "${REFERENCE}" "${GENERATED}"; then
    echo "The public API differs from api/SceytChatUIKit.swiftinterface." >&2
    echo "Run scripts/check_public_api.sh --update to accept an intentional change." >&2
    exit 1
fi

echo "The public API matches api/SceytChatUIKit.swiftinterface."
