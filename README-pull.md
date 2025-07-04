# Pull Script Usage Guide

## Overview
PowerShell script to clone/pull all repositories from the `vinaacademy` GitHub organization.

## Prerequisites
- PowerShell
- Git installed and configured
- GitHub personal access token (with repo read permissions)

## Usage

### Basic Usage
```powershell
# Clone/pull all repos to parent directory
.\pull.ps1

# Clone/pull all repos to specific path
.\pull.ps1 -Path "C:\MyProjects"
```

### First Run
1. Script will open GitHub token creation page
2. Create token with `repo` or `public_repo` permissions
3. Copy and paste token when prompted
4. Token is saved locally for future use

### Logout
```powershell
# Remove saved token
.\pull.ps1 -Logout
```

## Features
- ✅ Auto-saves GitHub token
- ✅ Clones new repositories
- ✅ Pulls updates for existing repositories
- ✅ Uses default branch for each repo
- ✅ Handles organization pagination

## Token Storage
Token is stored at: `$HOME\.github_token.txt`
