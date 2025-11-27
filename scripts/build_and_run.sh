#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# The directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Run the build script
"$SCRIPT_DIR/build.sh"

# Run the benchmark script
"$SCRIPT_DIR/run.sh" "$@"