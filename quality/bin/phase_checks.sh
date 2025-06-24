#!/usr/bin/env bash
set -euo pipefail
QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf "Universal Code Quality System\n"
printf "================================\n"

techs=$("$QUALITY_DIR/lib/detect_tech.sh" "$@")
printf "Detected: %s\n" "${techs:-none}"

if [[ "${techs:-none}" == "none" ]]; then
    printf "No supported technologies detected. Exiting.\n"
    exit 0
fi

OVERALL_EXIT_CODE=0

IFS=',' read -ra TECH_ARRAY <<< "$techs"
for tech in "${TECH_ARRAY[@]}"; do
    tech=$(echo "$tech" | tr -d ' ')
    printf "\n--- Running %s quality checks ---\n" "$tech"
    
    case "$tech" in
        shell)
            if "$QUALITY_DIR/bin/check_shell_quality.sh"; then
                printf "✅ Shell quality checks passed\n"
            else
                printf "❌ Shell quality checks failed\n"
                OVERALL_EXIT_CODE=1
            fi
            ;;
        python)
            printf "Python quality checks not yet implemented\n"
            ;;
        js|ts|react)
            printf "JavaScript/TypeScript quality checks not yet implemented\n"
            ;;
        html)
            printf "HTML quality checks not yet implemented\n"
            ;;
        css)
            printf "CSS quality checks not yet implemented\n"
            ;;
        *)
            printf "Unknown technology: %s\n" "$tech"
            ;;
    esac
done

printf "\n=== OVERALL SUMMARY ===\n"
if [[ $OVERALL_EXIT_CODE -eq 0 ]]; then
    printf "✅ All quality checks passed!\n"
else
    printf "❌ Some quality checks failed\n"
fi

exit $OVERALL_EXIT_CODE
