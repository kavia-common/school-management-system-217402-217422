#!/bin/bash
set -euo pipefail

# Applies schema_and_seed.sql to the configured PostgreSQL database.
# Uses db_connection.txt as the authoritative connection string.
#
# Usage:
#   ./apply_schema.sh

if [ ! -f "db_connection.txt" ]; then
  echo "db_connection.txt not found. Start the DB first (startup.sh) so it can generate connection info."
  exit 1
fi

CONN="$(cat db_connection.txt | tr -d '\n' | tr -d '\r')"
if [ -z "${CONN}" ]; then
  echo "db_connection.txt is empty."
  exit 1
fi

if [ ! -f "schema_and_seed.sql" ]; then
  echo "schema_and_seed.sql not found."
  exit 1
fi

echo "Applying schema_and_seed.sql using:"
echo "  ${CONN}"

# -v ON_ERROR_STOP=1 ensures the process stops on first error.
psql "${CONN}" -v ON_ERROR_STOP=1 -f schema_and_seed.sql

echo "✓ Schema + seed applied successfully"
