#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Step 1: Restore custom dump
echo "==> Restoring custom dump..."
pg_restore --username="${POSTGRES_USER}" \
           --dbname="${POSTGRES_DB}" \
           --no-owner \
           /tmp/practicum_sql_for_dev_project_3.sql &
restore_pid=$!

# Wait for the dump restoration to complete
echo "==> Waiting for dump restoration to complete..."
while kill -0 "$restore_pid" 2>/dev/null; do
    sleep 1
done
echo "==> Dump restoration completed!"

# Step 2: Wait for Postgres to be ready
echo "==> Waiting for Postgres to be ready..."
until pg_isready --username="${POSTGRES_USER}" --dbname="${POSTGRES_DB}" --quiet; do
    sleep 1
done
echo "==> Postgres is ready!"

# Step 3: Execute additional scripts
echo "Running additional procedures script creation..."
psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/extra-scripts-procedures.sql

# Step 4: Execute additional table with trigger creation
echo "Running additional table with trigger creation..."
psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/extra-scripts-table-with-trigger-creation.sql

# Step 5: Execute additional function creation
echo "Running additional function creation..."
psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/extra-scripts-function-creation.sql

