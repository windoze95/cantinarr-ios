#!/bin/sh

# Runs SwiftLint and SwiftFormat using shared configuration files

if command -v swiftlint >/dev/null; then
  swiftlint --config "$PROJECT_DIR/.swiftlint.yml"
else
  echo "warning: SwiftLint not installed" >&2
fi

if command -v swiftformat >/dev/null; then
  swiftformat "$PROJECT_DIR/Cantinarr" --config "$PROJECT_DIR/.swiftformat"
else
  echo "warning: SwiftFormat not installed" >&2
fi
