#!/bin/bash
set -e

# Use environment variables with defaults
DB_USER="${PGUSER:-${POSTGRES_USER:-postgres}}"
DB_NAME="${PGDATABASE:-${POSTGRES_DB:-vinaacademy}}"

# Function to create database if not exists
create_db_if_not_exists() {
    local db=$1
    echo "Checking database: $db"
    
    # Check if database exists
    if psql -U "$DB_USER" -d "$DB_NAME" -lqt | cut -d \| -f 1 | grep -qw "$db"; then
        echo "Database $db already exists"
    else
        echo "Creating database $db..."
        psql -U "$DB_USER" -d "$DB_NAME" -c "CREATE DATABASE $db;"
        echo "Database $db created"
    fi
    
    # Enable pgvector on the database
    echo "Enabling pgvector extension on $db..."
    psql -U "$DB_USER" -d "$db" -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || echo "pgvector may already be enabled on $db"
}

echo "Ensuring databases exist..."
echo "Using user: $DB_USER, database: $DB_NAME"

# Create required databases
create_db_if_not_exists "vinaacademy"
create_db_if_not_exists "vinaacademy_email"
create_db_if_not_exists "vinaacademy_chat"

echo "Database initialization completed!"
