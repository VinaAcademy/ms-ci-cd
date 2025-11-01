#!/bin/bash
set -e

echo "Waiting for PostgreSQL to be ready..."

# Wait for PostgreSQL to be ready
until pg_isready -h postgres -U postgres; do
  echo "PostgreSQL is unavailable - waiting..."
  sleep 2
done

echo "PostgreSQL is ready - creating databases..."

# Function to create database if it doesn't exist
create_database_if_not_exists() {
  local db_name=$1
  echo "Checking if database $db_name exists..."
  
  if psql -h postgres -U postgres -d vinaacademy -lqt | cut -d \| -f 1 | grep -qw $db_name; then
    echo "Database $db_name already exists"
  else
    echo "Creating database $db_name..."
    psql -h postgres -U postgres -d vinaacademy -c "CREATE DATABASE $db_name;"
    echo "Database $db_name created successfully"
  fi
}

# Create all required databases
create_database_if_not_exists "vinaacademy"
create_database_if_not_exists "vinaacademy_email"
create_database_if_not_exists "vinaacademy_chat"

echo "Database initialization completed!"
