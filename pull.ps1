param (
    [string]$Path = "..",
    [switch]$Logout
)

$orgName = "vinaacademy"
$tokenFile = "$HOME\.github_token.txt"
$perPage = 100

# ===== Dang xuat neu co tham so --Logout =====
if ($Logout) {
    if (Test-Path $tokenFile) {
        Remove-Item $tokenFile
        Write-Host "Da xoa token va dang xuat thanh cong."
    } else {
        Write-Host "Khong co token de xoa."
    }
    return
}

# ===== Lay token (co luu) =====
function Get-GitHubToken {
    if (Test-Path $tokenFile) {
        return Get-Content $tokenFile -Raw
    } else {
        Write-Host "Chua co token. Dang mo trinh duyet de tao..."
        Start-Process "https://github.com/settings/tokens"
        $newToken = Read-Host "Nhap GitHub Token cua ban (chi can quyen doc repo)"
        Set-Content -Path $tokenFile -Value $newToken
        Write-Host "Token da luu tai $tokenFile"
        return $newToken
    }
}

# Lap cho den khi token dung
do {
    $token = Get-GitHubToken

    # Goi thu API 1 lan de xac thuc token
    $url = "https://api.github.com/orgs/$orgName/repos?per_page=1&page=1"
    $headers = @{
        Authorization = "token $token"
        'User-Agent'  = 'PowerShellScript'
    }

    try {
        $test = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        $tokenValid = $true
    } catch {
        Write-Host "Token khong hop le hoac het han."
        Remove-Item $tokenFile -Force
        $tokenValid = $false
    }
} while (-not $tokenValid)

# ===== Chuan hoa duong dan =====
if (!(Test-Path -Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}
$destinationPath = Resolve-Path -Path $Path

# ===== Lay toan bo repos =====
$allRepos = @()
$page = 1
$maxRetries = 3
do {
    $url = "https://api.github.com/orgs/$orgName/repos?per_page=$perPage&page=$page"
    $retryCount = 0
    $success = $false
    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            $success = $true
        } catch {
            $retryCount++
            if ($retryCount -ge $maxRetries) {
                Write-Host "Failed to fetch repositories from GitHub API after $maxRetries attempts. Error: $($_.Exception.Message)" -ForegroundColor Red
                exit 1
            } else {
                Write-Host "Error fetching repositories (attempt $retryCount of $maxRetries). Retrying..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
    }
    $allRepos += $response
    $page++
} while ($response.Count -eq $perPage)

# ===== Clone hoac Pull theo default_branch =====
foreach ($repo in $allRepos) {
    $repoName = $repo.name
    $cloneUrl = $repo.clone_url
    $defaultBranch = $repo.default_branch
    $localRepoPath = Join-Path $destinationPath $repoName

    if (Test-Path -Path $localRepoPath) {
        Write-Host "🔄 Pulling $repoName ($defaultBranch)..."
        Push-Location $localRepoPath
        git fetch origin
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to fetch from origin in $repoName."
            Pop-Location
            return
        }

        git checkout $defaultBranch
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to checkout branch $defaultBranch in $repoName."
            Pop-Location
            return
        }

        git pull origin $defaultBranch
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to pull $defaultBranch from origin in $repoName."
            Pop-Location
            return
        }

        Pop-Location
    } else {
        Write-Host "Cloning $repoName ($defaultBranch)..."
        git clone --branch $defaultBranch $cloneUrl $localRepoPath
    }
}

Write-Host "Hoan tat pull/clone toan bo repo vao '$destinationPath'."
