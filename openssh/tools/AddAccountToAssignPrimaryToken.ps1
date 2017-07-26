﻿param($accountToAdd)
#written by Ingo Karstein, http://blog.karstein-consulting.com
#  v1.0, 01/03/2014

## <--- Configure here

if( [string]::IsNullOrEmpty($accountToAdd) ) {
	Write-Host "no account specified"
	exit
}

## ---> End of Config

$sidstr = $null
try {
	$ntprincipal = new-object System.Security.Principal.NTAccount "$accountToAdd"
	$sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	$sidstr = $sid.Value.ToString()
} catch {
	$sidstr = $null
}

Write-Host "Account: $($accountToAdd)" -ForegroundColor DarkCyan

if( [string]::IsNullOrEmpty($sidstr) ) {
	Write-Host "Account not found!" -ForegroundColor Red
	exit -1
}

Write-Host "Account SID: $($sidstr)" -ForegroundColor DarkCyan

$tmp = [System.IO.Path]::GetTempFileName()
#$tmp = Join-path -Path ([Environment]::GetEnvironmentVariable('TEMP', 'Machine')) -ChildPath ([System.IO.Path]::GetRandomFileName())

Write-Host "Export current Local Security Policy" -ForegroundColor DarkCyan
secedit.exe /export /cfg "$($tmp)"

$c = Get-Content -Path $tmp

#Remove-Item $tmp -Force -ErrorAction SilentlyContinue

$currentSetting = ""

foreach($s in $c) {
	if( $s -like "SeAssignPrimaryTokenPrivilege*") {
		$x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		$currentSetting = $x[1].Trim()
	}
}

if( $currentSetting -notlike "*$($sidstr)*" ) {
	Write-Host "Modify Setting ""Replace a process level token""" -ForegroundColor DarkCyan

	if( [string]::IsNullOrEmpty($currentSetting) ) {
		$currentSetting = "*$($sidstr)"
	} else {
		$currentSetting = "*$($sidstr),$($currentSetting)"
	}

	Write-Host "$currentSetting"

	$outfile = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeAssignPrimaryTokenPrivilege = $($currentSetting)
"@

	$tmp2 = [System.IO.Path]::GetTempFileName()
	#$tmp2 = Join-path -Path ([Environment]::GetEnvironmentVariable('TEMP', 'Machine')) -ChildPath ([System.IO.Path]::GetRandomFileName())


	Write-Host "Import new settings to Local Security Policy" -ForegroundColor DarkCyan
	$outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force

	#notepad.exe $tmp2
	Push-Location (Split-Path $tmp2)

	try {
		secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS
		#write-host "secedit.exe /configure /db ""secedit.sdb"" /cfg ""$($tmp2)"" /areas USER_RIGHTS "
	} finally {
		Pop-Location
	}
	#Remove-Item $tmp2 -force -ErrorAction SilentlyContinue
} else {
	Write-Host "NO ACTIONS REQUIRED! Account already in ""Replace a process level token""" -ForegroundColor DarkCyan
}

Write-Host "Done." -ForegroundColor DarkCyan
