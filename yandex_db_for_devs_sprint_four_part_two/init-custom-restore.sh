#!/bin/bash

# Database connection details
DB_NAME="local_delivery_service_db"
DB_USER="admin"

set -e  # Exit immediately if a command exits with a non-zero status

# Step 1: Restore custom dump
echo "==> Restoring custom dump..."
pg_restore --username="${POSTGRES_USER}" \
           --dbname="${POSTGRES_DB}" \
           --no-owner \
           /tmp/project_4_part2.sql &
restore_pid=$!

# Wait for the dump restoration to complete
echo "==> Waiting for dump restoration to complete..."
while kill -0 "$restore_pid" 2>/dev/null; do
    sleep 1
done
echo "==> Dump restoration completed!"

# Step 2: Enable pg_stat_statements
echo "==> Enabling pg_stat_statements..."
psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';"
psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT pg_reload_conf();"
psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
echo "==> pg_stat_statements enabled!"

# Step 3: Restart PostgreSQL to apply changes
echo "==> Restarting PostgreSQL to apply changes..."
pg_ctl restart -D "$PGDATA"

# Step 4: Wait for Postgres to be ready
echo "==> Waiting for Postgres to be ready..."
until pg_isready --username="${POSTGRES_USER}" --dbname="${POSTGRES_DB}" --quiet; do
    sleep 1
done
echo "==> Postgres is ready!"

# Step 5: Check table structures and indexes
TABLES=("cities" "dishes" "dishes_prices" "order_items" "order_statuses" "orders" "partners" "payments" "statuses" "user_logs" "user_logs_y2021q2" "user_logs_y2021q3" "user_logs_y2021q4" "users")

echo "Table structures and indexes for $DB_NAME"

for TABLE in "${TABLES[@]}"; do
    echo -e "\nStructure of table: $TABLE\n"
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "\d+ $TABLE"
    
    echo -e "\nIndexes for table: $TABLE\n"
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = '$TABLE';"
done

echo "Table structures and indexes printed to console"

# Step 6: Execute additional scripts
echo "Running additional scripts..."
psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/user_scripts_pr4.sql

# Step 7: Execute additional scripts
echo "Running additional scripts..."
psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/extra-scripts-db-optimization.sql