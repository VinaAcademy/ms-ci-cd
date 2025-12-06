-- Create databases
-- This script runs on PostgreSQL first initialization

-- Create vinaacademy_email database
CREATE DATABASE vinaacademy_email;

-- Create vinaacademy_chat database  
CREATE DATABASE vinaacademy_chat;

-- Enable pgvector extension on main database
CREATE EXTENSION IF NOT EXISTS vector;

-- Connect to vinaacademy_email and enable pgvector
\c vinaacademy_email
CREATE EXTENSION IF NOT EXISTS vector;

-- Connect to vinaacademy_chat and enable pgvector
\c vinaacademy_chat
CREATE EXTENSION IF NOT EXISTS vector;
