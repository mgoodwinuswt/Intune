# Requires -Version 3
<#
.SYNOPSIS
    Creates a scheduled task to enable folder redirection at user login.
    Enable folder redirection on Windows 10 Azure AD joined PCs.
    Downloads the folder redirection script from a URL locally and creates the schedule task.
#>
[CmdletBinding(ConfirmImpact = 'Low', HelpURI = 'https://stealthpuppy.com/', SupportsPaging = $False,
    SupportsShouldProcess = $False, PositionalBinding = $False)]
Param (
    [Parameter()]$LogFile = "$env:ProgramData\stealthpuppy\Logs\$($MyInvocation.MyCommand.Name).log",
    [Parameter()]$Source = "https://stlhppymdrn.blob.core.windows.net/fslogix-ruleset/?comp=list",
    [Parameter()]$RegPath = "HKLM:\SOFTWARE\FSLogix\Apps",
    [Parameter()]$RegExDirectory = "^[a-zA-Z]:\\[\\\S|*\S]?.*$",
    [Parameter()]$Target = "$env:ProgramData\stealthpuppy\Scripts",
    [Parameter()]$Url = "https://raw.githubusercontent.com/aaronparker/intune/master/Folder-Redirection/Redirect-Folders.ps1",
    [Parameter()]$Script = "Redirect-Folders.ps1",
    [Parameter()]$ScriptVb = "Redirect-Folders.vbs",
    [Parameter()]$TaskName = "Folder Redirection",
    [Parameter()]$Group = "BUILTIN\Users",
    [Parameter()]$Execute = "wscript.exe",
    [Parameter()]$Arguments = "$Target\$ScriptVb /b /nologo",
    [Parameter()]$VerbosePreference = "Continue"
)
Start-Transcript -Path $LogFile

# Construct string to output as a VBscript
$Vbscript = 'Set objShell=CreateObject("WScript.Shell")' + "`r`n"
$Vbscript = $Vbscript + 'Set objFSO=CreateObject("Scripting.FileSystemObject")' + "`r`n"
$Vbscript = $Vbscript + 'strCMD = "powershell -ExecutionPolicy Bypass -NonInteractive -WindowStyle Minimized -File ' + "$Target\$Script" + '"' + "`r`n"
$Vbscript = $Vbscript + 'objShell.Run strCMD,0'

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force -Verbose }

# Download the script from the source repository; output the VBscript
If (Test-Path "$Target\$Script") { Remove-Item -Path "$Target\$Script" -Force -Verbose }
Start-BitsTransfer -Source $Url -Destination "$Target\$Script" -Priority Foreground -TransferPolicy Always -ErrorAction SilentlyContinue -ErrorVariable $TransferError -Verbose
$Vbscript | Out-File -FilePath "$Target\$ScriptVb" -Force -Encoding ascii -Verbose

# Get an existing local task if it exists
If ($Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue -Verbose ) { 

    Write-Verbose "Folder redirection task exists."
    # If the task Action differs from what we have above, update the values and save the task
    If (!( ($Task.Actions[0].Execute -eq $Execute) -and ($Task.Actions[0].Arguments -eq $Arguments) )) {
        Write-Verbose "Updating scheduled task."
        $Task.Actions[0].Execute = $Execute
        $Task.Actions[0].Arguments = $Arguments
        $Task | Set-ScheduledTask -Verbose
    }
    Else {
        Write-Verbose "Existing task action is OK, no change required."
    }
}
Else {
    Write-Verbose "Creating folder redirection scheduled task."
    # Build a new task object
    $action = New-ScheduledTaskAction -Execute $Execute -Argument $Arguments -Verbose
    $trigger = New-ScheduledTaskTrigger -AtLogon -RandomDelay (New-TimeSpan -Minutes 1) -Verbose
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Hidden -DontStopIfGoingOnBatteries -Compatibility Win8 -Verbose
    $principal = New-ScheduledTaskPrincipal -GroupId $Group -Verbose
    $newTask = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Verbose

    # No task object exists, so register the new task
    Register-ScheduledTask -InputObject $newTask -TaskName $TaskName -Verbose
}
Stop-Transcript