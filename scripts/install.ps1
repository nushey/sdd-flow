# install.ps1 — install sdd-flow into any supported agentic client (Windows).
#
# sdd-flow is an Agent Skills + subagents pack (agentskills.io), NOT an MCP
# server. This script copies the 5 skills into the client's skill directory and
# the 5 subagent prompts into the client's agent directory, in the right shape.
#
# Usage:
#   scripts\install.ps1 -Client <codex|opencode|kilo|cursor|windsurf|antigravity> `
#                       [-Target <dir> | -Global] [-Source <path|url>]
#
#   # One-liner from anywhere (clones sdd-flow to a cache):
#   irm https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.ps1 | `
#     iex  # (then run: install.ps1 -Client codex)  — see README for the saved-file flow
#
#   # Or run from a local clone (auto-detected, no network):
#   git clone https://github.com/nushey/sdd-flow; sdd-flow\scripts\install.ps1 -Client kilo
#
#   # Global (user-level, all-projects) install instead of a project:
#   sdd-flow\scripts\install.ps1 -Client codex -Global

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('codex','opencode','kilo','cursor','windsurf','antigravity')]
    [string]$Client,

    [string]$Target = (Get-Location).Path,

    [switch]$Global,

    [string]$Source
)

$ErrorActionPreference = 'Stop'
$RepoUrl = 'https://github.com/nushey/sdd-flow.git'
$Cache = if ($env:SDD_FLOW_CACHE) { $env:SDD_FLOW_CACHE } else { Join-Path $HOME '.cache' 'sdd-flow' }
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is required.'
}

function Resolve-Source {
    if ($Source) {
        if ($Source -match '^https?://' -or $Source -match '^git@') {
            Clone-OrUpdate $Source $Cache
            return $Cache
        }
        return (Resolve-Path $Source).Path
    }
    $repoLocal = Join-Path $ScriptDir '..'
    if ((Test-Path (Join-Path $repoLocal 'skills')) -and (Test-Path (Join-Path $repoLocal 'agents'))) {
        return (Resolve-Path $repoLocal).Path
    }
    Clone-OrUpdate $RepoUrl $Cache
    return $Cache
}

function Clone-OrUpdate($url, $dest) {
    if (Test-Path (Join-Path $dest '.git')) {
        Write-Host "Updating cached sdd-flow at $dest"
        git -C $dest fetch --depth 1 origin HEAD 2>$null
        git -C $dest checkout -q FETCH_HEAD 2>$null
    } else {
        Write-Host "Cloning sdd-flow from $url"
        git clone --depth 1 $url $dest | Out-Null
    }
}

function Copy-Skills($src, $destSkills) {
    New-Item -ItemType Directory -Force -Path $destSkills | Out-Null
    foreach ($d in Get-ChildItem -Path (Join-Path $src 'skills') -Directory) {
        $target = Join-Path $destSkills $d.Name
        if (Test-Path $target) { Remove-Item -Recurse -Force $target }
        Copy-Item -Recurse $d.FullName $target
        Write-Host "  skill:  $($d.Name)"
    }
}

function Emit-OpencodeAgent($srcFile, $destFile) {
    # Insert `mode: subagent` after the opening frontmatter delimiter.
    $lines = Get-Content -LiteralPath $srcFile
    $out = New-Object System.Collections.Generic.List[string]
    if ($lines.Count -gt 0 -and $lines[0] -match '^---\s*$') {
        $out.Add($lines[0])
        $out.Add('mode: subagent')
        for ($i = 1; $i -lt $lines.Count; $i++) { $out.Add($lines[$i]) }
    } else {
        foreach ($l in $lines) { $out.Add($l) }
    }
    Set-Content -LiteralPath $destFile -Value $out
}

function Install-Client($src, $target, $client) {
    switch ($client) {
        'codex' {
            Copy-Skills $src (Join-Path $target '.agents' 'skills')
            $agentsDir = Join-Path $target '.codex' 'agents'; New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
            foreach ($f in Get-ChildItem -Path (Join-Path $src 'integrations' 'codex' 'agents') -Filter *.toml -File) {
                Copy-Item $f.FullName (Join-Path $agentsDir $f.Name)
                Write-Host "  agent:  .codex/agents/$($f.Name)"
            }
        }
        'opencode' {
            Copy-Skills $src (Join-Path $target '.agents' 'skills')
            $agentsDir = Join-Path $target '.opencode' 'agents'; New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
            foreach ($f in Get-ChildItem -Path (Join-Path $src 'agents') -Filter *.md -File) {
                Emit-OpencodeAgent $f.FullName (Join-Path $agentsDir $f.Name)
                Write-Host "  agent:  .opencode/agents/$($f.Name)"
            }
        }
        'kilo' {
            Copy-Skills $src (Join-Path $target '.agents' 'skills')
            $agentsDir = Join-Path $target '.kilo' 'agent'; New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
            foreach ($f in Get-ChildItem -Path (Join-Path $src 'agents') -Filter *.md -File) {
                Copy-Item $f.FullName (Join-Path $agentsDir $f.Name)
                Write-Host "  agent:  .kilo/agent/$($f.Name)"
            }
        }
        'cursor' {
            Copy-Skills $src (Join-Path $target '.agents' 'skills')
            $agentsDir = Join-Path $target '.cursor' 'agents'; New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
            foreach ($f in Get-ChildItem -Path (Join-Path $src 'agents') -Filter *.md -File) {
                Copy-Item $f.FullName (Join-Path $agentsDir $f.Name)
                Write-Host "  agent:  .cursor/agents/$($f.Name)"
            }
        }
        'windsurf' {
            Copy-Skills $src (Join-Path $target '.agents' 'skills')
            $rulesDir = Join-Path $target '.devin' 'rules'; New-Item -ItemType Directory -Force -Path $rulesDir | Out-Null
            $rulesSrc = Join-Path $src 'integrations' 'windsurf' 'windsurfrules'
            Copy-Item $rulesSrc (Join-Path $rulesDir 'sdd.md')
            Write-Host "  rules:  .devin/rules/sdd.md"
            Copy-Item $rulesSrc (Join-Path $target '.windsurfrules')
            Write-Host "  rules:  .windsurfrules (legacy)"
        }
        'antigravity' {
            Copy-Skills $src (Join-Path $target '.agents' 'skills')
        }
    }
}

function Install-ClientGlobal($src, $client) {
    switch ($client) {
        'codex' {
            Copy-Skills $src (Join-Path $HOME '.agents' 'skills')
            $agentsDir = Join-Path $HOME '.codex' 'agents'; New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
            foreach ($f in Get-ChildItem -Path (Join-Path $src 'integrations' 'codex' 'agents') -Filter *.toml -File) {
                Copy-Item $f.FullName (Join-Path $agentsDir $f.Name)
                Write-Host "  agent:  ~/.codex/agents/$($f.Name)"
            }
        }
        'opencode' {
            Copy-Skills $src (Join-Path $HOME '.config' 'opencode' 'skills')
            $agentsDir = Join-Path $HOME '.config' 'opencode' 'agents'; New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
            foreach ($f in Get-ChildItem -Path (Join-Path $src 'agents') -Filter *.md -File) {
                Emit-OpencodeAgent $f.FullName (Join-Path $agentsDir $f.Name)
                Write-Host "  agent:  ~/.config/opencode/agents/$($f.Name)"
            }
        }
        'kilo' {
            Copy-Skills $src (Join-Path $HOME '.kilo' 'skills')
            $agentsDir = Join-Path $HOME '.kilo' 'agent'; New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
            foreach ($f in Get-ChildItem -Path (Join-Path $src 'agents') -Filter *.md -File) {
                Copy-Item $f.FullName (Join-Path $agentsDir $f.Name)
                Write-Host "  agent:  ~/.kilo/agent/$($f.Name)"
            }
        }
        'cursor' {
            Write-Host '  skip:   global skills -- no confirmed user-level skills directory for Cursor.'
            $agentsDir = Join-Path $HOME '.cursor' 'agents'; New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
            foreach ($f in Get-ChildItem -Path (Join-Path $src 'agents') -Filter *.md -File) {
                Copy-Item $f.FullName (Join-Path $agentsDir $f.Name)
                Write-Host "  agent:  ~/.cursor/agents/$($f.Name)"
            }
        }
        'windsurf' {
            Copy-Skills $src (Join-Path $HOME '.codeium' 'windsurf' 'skills')
            Write-Host '  skip:   global rules -- no confirmed user-level rules directory for Windsurf/Devin Desktop.'
            Write-Host '          Install rules per-project: scripts\install.ps1 -Client windsurf -Target <dir>'
        }
        'antigravity' {
            Copy-Skills $src (Join-Path $HOME '.gemini' 'config' 'skills')
        }
    }
}

function Invoke-Hint($client) {
    switch ($client) {
        'codex'       { '  - Type /skills or use the agent to load the ''sdd'' skill; run /sdd <feature>.' }
        'opencode'    { '  - The agent auto-loads the ''sdd'' skill; say ''/sdd <feature>'' or ''@sdd-developer ...''.' }
        'kilo'        { '  - Use the ''sdd'' skill; say ''/sdd <feature>''.' }
        'cursor'      { '  - Type /sdd or let the agent load the ''sdd'' skill by asking to ''spec this''.' }
        'windsurf'    { '  - Say ''/sdd <feature>'' or ''use SDD to plan <feature>'' (rules-driven orchestrator).' }
        'antigravity' { '  - Ask the agent to use the ''sdd'' skill, or say ''use SDD for <feature>''.' }
    }
}

$src = Resolve-Source
$src = (Resolve-Path $src).Path
if (-not (Test-Path (Join-Path $src 'skills')) -or -not (Test-Path (Join-Path $src 'agents'))) {
    throw "source has no skills/ and agents/ ($src)"
}

if ($Global) {
    Write-Host "Installing sdd-flow for '$Client' (global, user-level)"
    Write-Host "  source: $src"

    Install-ClientGlobal $src $Client

    Write-Host ''
    Write-Host "Done. sdd-flow is installed for $Client (global -- applies to every project on this machine)."
    Write-Host ''
    Write-Host 'Before you start:'
    Write-Host '  - Every project you use sdd-flow in still needs its own AGENTS.md at the root'
    Write-Host '    (user-provided; SDD never creates it). Global install only skips re-copying'
    Write-Host '    skills/agents per project -- it does not skip that precondition.'
    Write-Host '  - Install the GitHub CLI (gh) and run `gh auth login` — the Verifier opens PRs with it.'
    Write-Host ''
    Write-Host 'Invoke:'
    Invoke-Hint $Client
    Write-Host ''
    Write-Host 'Re-run this command any time to refresh skills/agents.'
} else {
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    $target = (Resolve-Path $Target).Path

    Write-Host "Installing sdd-flow for '$Client'"
    Write-Host "  source: $src"
    Write-Host "  target: $target"

    Install-Client $src $target $Client

    Write-Host ''
    Write-Host "Done. sdd-flow is installed for $Client."
    Write-Host ''
    Write-Host 'Before you start:'
    Write-Host '  - Make sure your project has an AGENTS.md at the root (user-provided; SDD never creates it).'
    Write-Host '  - Install the GitHub CLI (gh) and run `gh auth login` — the Verifier opens PRs with it.'
    Write-Host ''
    Write-Host 'Invoke:'
    Invoke-Hint $Client
    Write-Host ''
    Write-Host 'Re-run this command any time to refresh skills/agents.'
}
