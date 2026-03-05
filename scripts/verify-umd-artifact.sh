#!/bin/bash
# Verification script for UMD artifact
# Checks version, format, and basic functionality

set -e

ARTIFACT="Sources/LightweightCharts/Assets/lightweight-charts.js"
EXPECTED_VERSION=${1:-5.1.0}

echo "Verifying UMD artifact..."

# Check file exists
if [ ! -f "${ARTIFACT}" ]; then
    echo "✗ Error: Artifact not found at ${ARTIFACT}"
    exit 1
fi
echo "✓ Artifact exists"

# Check version in header
HEADER=$(head -10 "${ARTIFACT}")
if echo "${HEADER}" | grep -q "Lightweight Charts.*${EXPECTED_VERSION}"; then
    echo "✓ Version confirmed: ${EXPECTED_VERSION}"
else
    echo "✗ Version mismatch. Expected: ${EXPECTED_VERSION}"
    echo "Header: ${HEADER}"
    exit 1
fi

# Check for required UMD/IIFE pattern
if grep -q "typeof exports === 'object'" "${ARTIFACT}" || \
   grep -q "!function(" "${ARTIFACT}"; then
    echo "✓ UMD/IIFE format detected"
else
    echo "✗ UMD/IIFE format not detected"
    exit 1
fi

# Check for required lightweight-charts exports
REQUIRED_EXPORTS=(
    "createChart"
    "LineSeries"
    "CandlestickSeries"
    "BarSeries"
    "AreaSeries"
    "HistogramSeries"
    "BaselineSeries"
)

MISSING=0
for export in "${REQUIRED_EXPORTS[@]}"; do
    if grep -q "${export}" "${ARTIFACT}"; then
        echo "  ✓ Found: ${export}"
    else
        echo "  ✗ Missing: ${export}"
        MISSING=1
    fi
done

if [ $MISSING -eq 1 ]; then
    echo "✗ Some required exports are missing"
    exit 1
fi

# Check file size is reasonable (between 100KB and 500KB for production build)
SIZE=$(wc -c < "${ARTIFACT}")
if [ $SIZE -gt 100000 ] && [ $SIZE -lt 500000 ]; then
    echo "✓ File size reasonable: $SIZE bytes"
else
    echo "⚠ Warning: Unusual file size: $SIZE bytes (expected 100KB-500KB)"
fi

echo ""
echo "✓ All verification checks passed!"
