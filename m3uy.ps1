
param(
    [Parameter()]
    [string] $Playlist
)

function Get-RemovableDriveIsValid {
    param(
        [Parameter()]
        [string] $DriveLetter
    )
    if ($DriveLetter.Length -ne 1) {
        return $false
    }
    $removableDriveLetters = (Get-WmiObject Win32_LogicalDisk | where { $_.DriveType -eq '2' }).DeviceID.Replace(':', '') # a list of removable drives
    if ($removableDriveLetters -notcontains $DriveLetter) {
        return $false
    }
    return $true
}

function Get-RemovableDrives {
    $rDisks = (Get-WmiObject Win32_LogicalDisk | where { $_.DriveType -eq '2' })
    if ($rDisks.Length -eq 0) {
        return $false
    }
    return (Get-WmiObject Win32_LogicalDisk | where { $_.DriveType -eq '2' } | Format-List -Property DeviceID, VolumeName) # show the user removable drives
}

function Get-M3UPlayListFiles {
    param(
        [Parameter()]
        [string] $playlist
    )
    $playListFiles = New-Object Collections.Generic.List[string]
    $invalidPlayListFiles = New-Object Collections.Generic.List[string]
    foreach ($line in [System.IO.File]::ReadLines($playlist)) {
        if ($line -match '^[^#]') {
            $uri = [System.Uri]($line)
            if ($uri.Scheme.Equals("file")) {
                if (Test-Path $uri.LocalPath) {
                    $playListFiles.Add($uri.LocalPath)
                }
            }        
        }
    }
    if ($invalidPlayListFiles.Length -gt 0) {
        Write-Output "WARNING Some files do not exist on system and will not be copied:`n$invalidPlayListFiles`n"
    }
    return $playListFiles
}

# -------------------------------- Check Environment --------------------------------------

# check for removable drive to copy files to, this is required

$removableDrives = Get-RemovableDrives
if ($removableDrives -eq $false) {
    return "`nNo removable drives found. Quitting.`n"
}

# check for existance of playlist file provided by user, a valid playlist file is required

if (Test-Path $playlist) {
    Write-Output "`nFound playlist file $PlayList"
}
else {
    return "`n$uri.LocalPath does not exist.`n"
}

# get the list of files to copy from the playlist, having valid files that can be found is required

$playListFiles = Get-M3UPlayListFiles($PlayList)
if ($playListFiles.Length -eq 0) {
    return "`nNo valid files found in the playlist.`n"
}

# -------------------------------- Get User Input --------------------------------------

# ask for removable drive to copy files to

Write-Output "`nAvailable Removable Drives:`n" $removableDrives
$driveletter = Read-Host "`nEnter the drive letter you wish to copy files to"
$isDriveLetterValid = Get-RemovableDriveIsValid -DriveLetter $driveletter
if ($isDriveLetterValid -eq $false) {
    return "`nRemovable drive not valid.`n"
}
$wmiDriveLetter = (Get-WmiObject Win32_LogicalDisk | where { $_.DeviceID -eq "$driveletter`:" }).DeviceID
$wmiDriveVolumeName = (Get-WmiObject Win32_LogicalDisk | where { $_.DeviceID -eq "$driveletter`:" }).VolumeName

# ask if a custom path is desired

$customizedPathString = Read-Host "`nEnter folder to copy files, e.g. 'Music' or '\Music\mp3', Enter for root"

# get the target path and validate it

if ($customizedPathString.StartsWith('\') -eq $false) {
    $customizedPathString = '\' + $customizedPathString
} 
$targetPath = ($wmiDriveLetter.Replace('\', '')) + "$customizedPathString"
if ((Test-Path -Path $targetPath) -eq $false) {
    $createDir = Read-Host "Directory $targetPath does not exist, create it?"
    if ($createDir.ToLower() -eq 'y') {
        New-Item -ItemType "directory" -Path "$targetPath"
    }
}

# -------------------------------- Prepare & Confirm Copy --------------------------------------

$fileCount = $playListFiles.Length
$confirm = Read-Host "`nCopy $fileCount file(s) to to $targetPath with volume name $wmiDriveVolumeName ? (y/n)"
if ($confirm.ToLower() -ne 'y') {
    return "`nOperation cancelled.`n"
}

# -------------------------------- Do Copy --------------------------------------

foreach ($playListFile in $playListFiles) {
    $uri = [System.Uri]($playListFile)
    if ($uri.Scheme.Equals("file")) {
        $fileName = [System.IO.Path]::GetFileName($uri.LocalPath)
        if ((Test-Path -Path "$targetPath\$fileName") -eq $false) {
            Write-Host $playListFile
            Copy-Item "$playListFile" -Destination "$targetPath"
        }
    }
}
