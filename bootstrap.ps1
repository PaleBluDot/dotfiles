# bootstrap.ps1: get Git Bash onto a Windows machine, then hand over to
# dotfiles.sh's own first run (plan.md Section 12).
#
# Run from PowerShell:
#   irm https://raw.githubusercontent.com/PaleBluDot/dotfiles/main/bootstrap.ps1 | iex
# Test a branch first:
#   $env:DOTFILES_BRANCH = "feat/dotfiles-script-rewrite"
#   irm https://raw.githubusercontent.com/PaleBluDot/dotfiles/$env:DOTFILES_BRANCH/bootstrap.ps1 | iex

# Everything runs inside a function: "irm | iex" runs this in your own
# PowerShell session, where "exit" would close the window. "return" doesn't.
function Invoke-DotfilesBootstrap {
    $branch = if ($env:DOTFILES_BRANCH) { $env:DOTFILES_BRANCH } else { 'main' }
    $scriptUrl = "https://raw.githubusercontent.com/PaleBluDot/dotfiles/$branch/dotfiles.sh"

    # 1. git. Git for Windows also brings bash.exe (Git Bash), which runs
    #    dotfiles.sh. PowerShell can't run .sh files itself.
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "[SUCCESS] git: $(git --version)"
    } else {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "[ERROR] winget isn't available; install 'App Installer' from the Microsoft Store, then run this again."
            return
        }
        Write-Host "[INFO] git: not installed, installing Git.Git with winget"
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] installing Git for Windows failed (winget exit code $LASTEXITCODE)"
            return
        }
    }

    # 2. bash.exe: the default install path first, then other common places.
    $bashCandidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    )
    $bashPath = $bashCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if (-not $bashPath) {
        Write-Host "[ERROR] Git Bash was installed but bash.exe could not be located. Please open a new PowerShell window and try again."
        return
    }
    Write-Host "[SUCCESS] bash: $bashPath"

    # 3. Symlinks. Windows only lets normal users make symlinks with
    #    Developer Mode on. Without it, linking configs fails (on purpose:
    #    dotfiles.sh refuses to fall back to copies).
    $devMode = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
        -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue
    if ($devMode -and $devMode.AllowDevelopmentWithoutDevLicense -eq 1) {
        Write-Host "[SUCCESS] Developer Mode: on (symlinks allowed)"
    } else {
        Write-Host "[WARN] Developer Mode is off, so dotfiles.sh can't make symlinks."
        Write-Host "[WARN] Turn it on: Settings > System > For developers > Developer Mode. Then run this again."
    }

    # 4. Hand over: dotfiles.sh's first run clones the repo, links itself
    #    into ~/bin and runs the interactive install. -l = login shell, so
    #    Git Bash sets up its PATH (curl, git). DOTFILES / DOTFILES_BRANCH
    #    carry over as environment variables.
    # nativestrict: ln -s makes a real symlink or fails; never a silent copy.
    $env:MSYS = 'winsymlinks:nativestrict'
    Write-Host "[INFO] running dotfiles.sh from $scriptUrl"
    & $bashPath -lc "curl -fsSL '$scriptUrl' | bash"
}

Invoke-DotfilesBootstrap
