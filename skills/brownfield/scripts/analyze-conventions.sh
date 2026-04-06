#!/bin/bash
set -e
# analyze-conventions.sh
# Samples source files to detect naming and formatting conventions.
# Output: JSON to stdout. Status: stderr.

echo "Analyzing code conventions..." >&2

FILE_NAMING="unknown"
IMPORT_STYLE="unknown"
QUOTE_STYLE="unknown"
SEMICOLONS="unknown"
PATH_ALIASES=""
ORG_PATTERN="unknown"

# Detect indent from editorconfig
INDENT_STYLE="spaces"
if [ -f ".editorconfig" ]; then
  grep -q "indent_style = tab" .editorconfig 2>/dev/null && INDENT_STYLE="tabs"
fi

# Sample TS/JS source files
SAMPLE_FILES=$(find src app lib -maxdepth 4 \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) 2>/dev/null | grep -v node_modules | head -20)

if [ -n "$SAMPLE_FILES" ]; then
  SINGLE=$(echo "$SAMPLE_FILES" | xargs grep -hc "'" 2>/dev/null | awk '{s+=$1}END{print s+0}')
  DOUBLE=$(echo "$SAMPLE_FILES" | xargs grep -hc '"' 2>/dev/null | awk '{s+=$1}END{print s+0}')
  [ "$SINGLE" -gt "$DOUBLE" ] && QUOTE_STYLE="single" || QUOTE_STYLE="double"

  SEMI=$(echo "$SAMPLE_FILES" | xargs grep -hcE ';$' 2>/dev/null | awk '{s+=$1}END{print s+0}')
  [ "$SEMI" -gt 20 ] && SEMICOLONS="yes" || SEMICOLONS="no"

  ABS=$(echo "$SAMPLE_FILES" | xargs grep -hcE "^import.*from '@" 2>/dev/null | awk '{s+=$1}END{print s+0}')
  REL=$(echo "$SAMPLE_FILES" | xargs grep -hcE "^import.*from '\.\." 2>/dev/null | awk '{s+=$1}END{print s+0}')
  [ "$ABS" -gt "$REL" ] && IMPORT_STYLE="absolute" || IMPORT_STYLE="relative"
fi

# Path aliases from tsconfig
if [ -f "tsconfig.json" ] && command -v node &>/dev/null; then
  PATH_ALIASES=$(node -e "
    try {
      const c = require('./tsconfig.json');
      const paths = c.compilerOptions && c.compilerOptions.paths;
      if (paths) console.log(Object.keys(paths).join(', '));
    } catch(e) {}
  " 2>/dev/null || echo "")
fi

# File naming pattern from actual filenames
KEBAB=$(find src app lib -maxdepth 4 \( -name "*-*.ts" -o -name "*-*.tsx" \) 2>/dev/null | wc -l)
PASCAL=$(find src app lib -maxdepth 4 -name "[A-Z]*.tsx" 2>/dev/null | wc -l)
if [ "$PASCAL" -gt "$KEBAB" ]; then FILE_NAMING="PascalCase"
elif [ "$KEBAB" -gt 0 ]; then FILE_NAMING="kebab-case"
fi

# Org structure
if [ -d "src/components" ] && [ -d "src/services" ]; then ORG_PATTERN="layer-based"
elif [ -d "src/features" ] || [ -d "src/modules" ]; then ORG_PATTERN="feature-based"
fi

echo "Conventions analyzed" >&2

cat <<EOF
{
  "file_naming": "$FILE_NAMING",
  "import_style": "$IMPORT_STYLE",
  "indent_style": "$INDENT_STYLE",
  "quote_style": "$QUOTE_STYLE",
  "semicolons": "$SEMICOLONS",
  "path_aliases": "$PATH_ALIASES",
  "org_pattern": "$ORG_PATTERN"
}
EOF
