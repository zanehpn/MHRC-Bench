#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../test_project"
export PATH="/tmp/sbt/bin:$PATH"
cd "$PROJECT_DIR"
sbt "testOnly asyncqueue.modules.SynchronizerRegTargetSpec"
