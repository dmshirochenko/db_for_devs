#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Step 1: Restore custom dump
echo "==> Restoring custom dump..."
pg_restore --username="${POSTGRES_USER}" \
           --dbname="${POSTGRES_DB}" \
           --no-owner \
           /tmp/sprint2_dump.sql &
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

# Step 3: Execute additional schema creation and data transformation
echo "Running additional schema and data transformation scripts..."
psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/extra-scripts-new-tables-creation.sql

# Step 4: Execute the migration script
echo "Running data migration script..."
psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/extra-scripts-data-insertion-from-raw-tables.sql

# Step 5: Create new views
echo "Creating new views..."
psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/extra-scripts-view-creation.sql

# Step 6: Running some analytical queries
echo "Running analytical queries..."
psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/extra-scripts-analytical-requests.sql

echo "Initialization and data migration completed."

