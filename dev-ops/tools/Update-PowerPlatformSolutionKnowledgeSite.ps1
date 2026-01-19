    param (
        [Parameter(Mandatory=$true)]
        [string]$DirectoryPath,

        [Parameter(Mandatory=$true)]
        [string]$KnowledgeSourceName,
        
        [Parameter(Mandatory=$true)]
        [string]$SiteUrl
    )

    Write-Host "Updating knowledge source $KnowledgeSourceName with Site Url $SiteUrl in directory: $DirectoryPath"

    # Search for a folder containing 'knowledge.$KnowledgeSourceName_' or 'topic.$KnowledgeSourceName_' in its name
    $knowledgeFolder = Get-ChildItem -Path $DirectoryPath -Directory -Recurse |
        Where-Object { $_.Name -like "*knowledge.$KnowledgeSourceName_*" } |
        Select-Object -First 1;

    if (-not $knowledgeFolder) {
        $knowledgeFolder = Get-ChildItem -Path $DirectoryPath -Directory -Recurse |
        Where-Object { $_.Name -like "*topic.$KnowledgeSourceName_*" } |
        Select-Object -First 1;
    }

     
    if (-not $knowledgeFolder) {
        Write-Error "Could not find a folder containing '*knowledge.$KnowledgeSourceName*' in '$DirectoryPath'.";
        return;
    }

    # Look for a file named 'data' in the found folder
    $dataFile = Join-Path $knowledgeFolder.FullName 'data'

    if (-not (Test-Path $dataFile)) {
        Write-Error "Data file 'data' not found in '$($knowledgeFolder.FullName)'."
        return
    }

    $content = Get-Content $dataFile -Raw

    # Ensure 'site:' is replaced only under the 'source:' section
    $contentLines = $content -split "`n"
    $inSource = $false
    for ($i = 0; $i -lt $contentLines.Length; $i++) {
        $line = $contentLines[$i].TrimEnd()
        if ($line -match '^\s*source:\s*$') {
            $inSource = $true
            continue
        }
        if ($inSource -and $line -match '^\s*site:\s*') {
            $indent = ($contentLines[$i] -match '^(\s*)site:') ? $matches[1] : ''
            $contentLines[$i] = "${indent}site: $SiteUrl"
            break
        }
        # End 'source:' section if another top-level key is found
        if ($inSource -and $line -match '^\S') {
            break
        }
    }
    $newContent = $contentLines -join "`n"
    # Update the 'site' value under 'source'
    $pattern = '(site:\s*)(\S+)'
    if ($content -match $pattern) {
        $newContent = $content -replace $pattern, "`$1$SiteUrl"
        Set-Content -Path $dataFile -Value $newContent
        Write-Host "Updated site URL in '$dataFile' to '$SiteUrl'."
    } else {
        Write-Error "Could not find 'site' property in '$dataFile'."
    }
