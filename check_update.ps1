param (
    [string]$Path = ".."
)

# ===== Chuan hoa duong dan =====
if (!(Test-Path -Path $Path))
{
    Write-Host "Duong dan $Path khong ton tai." -ForegroundColor Red
    exit 1
}

$destinationPath = Resolve-Path -Path $Path

# ===== Lay danh sach thu muc repo =====
$repos = Get-ChildItem -Path $destinationPath -Directory

foreach ($repo in $repos)
{
    $repoPath = $repo.FullName
    if (Test-Path -Path (Join-Path $repoPath ".git"))
    {
        Write-Host ""
        Write-Host "Kiem tra repo: $($repo.Name)..." -ForegroundColor Cyan
        Push-Location $repoPath

        # Lay branch hien tai
        $currentBranch = git rev-parse --abbrev-ref HEAD
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Khong the lay branch hien tai." -ForegroundColor Red
            Pop-Location
            continue
        }

        Write-Host "Branch hien tai: $currentBranch" -ForegroundColor Blue

        # Fetch origin de co thong tin moi nhat
        git fetch origin | Out-Null

        # Kiem tra trang thai push cua branch hien tai
        $status = git status -sb
        if ($status -match "ahead (\d+)") {
            Write-Host "Branch '$currentBranch' co $($matches[1]) commit chua duoc push len origin." -ForegroundColor Yellow
        } else {
            Write-Host "Branch '$currentBranch' da duoc push len origin." -ForegroundColor Green
        }

        # So sanh local branches va origin branches
        $localBranches = git for-each-ref --format="%(refname:short)" refs/heads/
        $untrackedBranches = @()

        foreach ($branch in $localBranches) {
            $remoteBranch = git ls-remote --heads origin $branch
            if (-not $remoteBranch) {
                $untrackedBranches += $branch
            }
        }

        if ($untrackedBranches.Count -gt 0) {
            Write-Host "Cac branch chua duoc day len origin:" -ForegroundColor Magenta
            $untrackedBranches | ForEach-Object { Write-Host " - $_" }
        } else {
            Write-Host "Tat ca cac branch da duoc day len origin." -ForegroundColor Green
        }

        Pop-Location
    }
    else
    {
        Write-Host "Thu muc $($repo.Name) khong phai la mot git repository." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Hoan tat kiem tra." -ForegroundColor Cyan
