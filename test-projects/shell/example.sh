#!/usr/bin/env bash
# Example shell script for testing quality pipeline

set -euo pipefail

# Function to greet someone
greet() {
    local name="$1"
    echo "Hello, $name!"
}

# Function to calculate sum
calculate_sum() {
    local sum=0
    for num in "$@"; do
        ((sum += num))
    done
    echo "$sum"
}

# Main script
main() {
    local name="${1:-World}"
    greet "$name"

    # Calculate sum of some numbers
    local result
    result=$(calculate_sum 1 2 3 4 5)
    echo "Sum: $result"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
