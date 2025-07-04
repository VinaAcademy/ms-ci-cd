param (
    [string]$Path = "..",
    [switch]$Logout
)

$orgName = "vinaacademy"
$tokenFile = "$HOME\.github_token.txt"
$perPage = 100

# ===== Đăng xuất nếu có tham số --Logout =====
if ($Logout) {
    if (Test-Path $tokenFile) {
        Remove-Item $tokenFile
        Write-Host "🚪 Đã xóa token và đăng xuất thành công."
    } else {
        Write-Host "⚠️ Không có token để xóa."
    }
    return
}

# ===== Lấy token (có lưu) =====
function Get-GitHubToken {
    if (Test-Path $tokenFile) {
        return Get-Content $tokenFile -Raw
    } else {
        Write-Host "🔐 Chưa có token. Đang mở trình duyệt để tạo..."
        Start-Process "https://github.com/settings/tokens"
        $newToken = Read-Host "👉 Nhập GitHub Token của bạn (chỉ cần quyền đọc repo)"
        Set-Content -Path $tokenFile -Value $newToken
        Write-Host "💾 Token đã lưu tại $tokenFile"
        return $newToken
    }
}

# Lặp cho đến khi token đúng
do {
    $token = Get-GitHubToken

    # Gọi thử API 1 lần để xác thực token
    $url = "https://api.github.com/orgs/$orgName/repos?per_page=1&page=1"
    $headers = @{
        Authorization = "token $token"
        'User-Agent'  = 'PowerShellScript'
    }

    try {
        $test = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        $tokenValid = $true
    } catch {
        Write-Host "❌ Token không hợp lệ hoặc hết hạn."
        Remove-Item $tokenFile -Force
        $tokenValid = $false
    }
} while (-not $tokenValid)

# ===== Chuẩn hóa đường dẫn =====
$destinationPath = Resolve-Path -Path $Path
if (!(Test-Path -Path $destinationPath)) {
    New-Item -ItemType Directory -Path $destinationPath | Out-Null
}

# ===== Lấy toàn bộ repos =====
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

# ===== Clone hoặc Pull theo default_branch =====
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
            Write-Host "❌ Failed to fetch from origin in $repoName."
            Pop-Location
            return
        }

        git checkout $defaultBranch
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to checkout branch $defaultBranch in $repoName."
            Pop-Location
            return
        }

        git pull origin $defaultBranch
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to pull $defaultBranch from origin in $repoName."
            Pop-Location
            return
        }

        Pop-Location
    } else {
        Write-Host "📥 Cloning $repoName ($defaultBranch)..."
        git clone --branch $defaultBranch $cloneUrl $localRepoPath
    }
}

Write-Host "✅ Hoàn tất pull/clone toàn bộ repo vào '$destinationPath'."
