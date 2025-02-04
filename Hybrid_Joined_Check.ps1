## Hybrid-Joined Check
## Benjamin Barshaw <benjamin.barshaw@ode.oregon.gov> - IT Operations & Support Network Team Lead - Oregon Department of Education
#
#  Requirements: Microsoft.Graph.Identity.DirectoryManagement PowerShell Module
#                Being connected to Microsoft Graph (Connect-MgGraph)  
#
#  This script checks to see if a computer is "Managed" using the Get-MgDevice cmdlet. I was looking for a method to check on hybrid-joined status for workstations with some form of automation as dsregcmd.exe doesn't have functionality
#  for remote workstations. I began cross-comparing return values of Get-MgDevice and came across the "IsManaged" property. This method can be adapted to not only cycle through Active Directory, but rather check status on EVERY 
#  workstation returned by Get-MgDevice regardless of which tenant/agency it is part of.

param(
    [int]$DaysBack = 7
)

class hybridReport
{
    [string]$Workstation
    [string]$DateJoined
    [string]$HybridStatus
}

$emailAddressToSendReportTo = "<CHANGE_TO_EMAIL_ADDRESS>" # Example: Benjamin.Barshaw@ode.oregon.gov
$emailAddressToSendReportFrom = "<CHANGE_TO_SENDER>" # Example: ODE Hybrid-Joined Report <no-reply@ode.oregon.gov>
$dateForEmail = Get-Date -Format MM/dd/yyyy # Doesn't need touching
$emailSubject = "<CHANGE_TO_SUBJECT>" # Example: ODE Hybrid-Joined Report - $($dateForEmail)
$smtpServerForEmail = "<CHANGE_TO_MAILSERVER>" # Example: smtp.agencyname.oregon.gov

$cssStyle = @"
<style>
body{font-family:Calibri;font-size:12pt;}
table{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse; padding-right:5px}
th{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:black;background-color:#FFFFFF }
th{border-width: 1px;padding: 5px;border-style: solid;border-color: black}
td{border-width: 1px;padding: 5px;border-style: solid;border-color: black}
</style>
"@

$startDate = (Get-Date).AddDays(-$DaysBack)
$startDateForEmail = Get-Date -Date $startDate -Format MM/dd/yyyy
$endDate = Get-Date


$getComputers = Get-ADComputer -Filter '(whenCreated -gt $startDate) -and (whenCreated -lt $endDate)' -Properties whenCreated
$getCount = $getComputers.Count

If ($getCount -gt 0)
{
    $emailArray = @()
}

Write-Host -ForegroundColor Cyan "Found $($getCount) computers domain-joined in the last $($DaysBack) days. Checking hybrid-joined status..."

ForEach ($domainPC in $getComputers)
{
    $getDate = Get-Date -Date $domainPC.whenCreated -Format "MM/dd/yyyy"
    $exportMe = [hybridReport]::new()
    $exportMe.Workstation = [string]$domainPC.Name
    $exportMe.DateJoined = [string]$getDate    

    If ((Get-MgDevice -Search "displayName:$($domainPC.Name)" -ConsistencyLevel eventual).IsManaged -eq $true)
    {        
        Write-Host -ForegroundColor Green "$($domainPC.Name) which was created on $($getDate) is hybrid-joined!"
        $exportMe.HybridStatus = "Hybrid-joined"
    }
    Else
    {
        Write-Host -ForegroundColor Red "$($domainPC.Name) which was created on $($getDate) is NOT hybrid-joined!"
        $exportMe.HybridStatus = "Domain"
    }    

    $emailArray += $exportMe
}

Write-Host -ForegroundColor Cyan "E-mail report to ODE IT Operations Network Team?"
$yesNo = Read-Host -Prompt "[Y/N]"
If ($yesNo -eq "y")
{
    $hybridHeader = "<H2>Workstations Joined to ODE Domain From $($stateDateForEmail)-$($dateForEmail) Hybrid-Joined Status - Count: $($getCount)</H2>"
    $generateEmail = $emailArray | ConvertTo-Html -Head $cssStyle -Body $hybridHeader -Title "ODE Hybrid-Joined Report"
    Send-MailMessage -To $emailAddressToSendReportTo -From $emailAddressToSendReportFrom -Subject $emailSubject -BodyAsHtml ($generateEmail | Out-String) -SmtpServer $smtpServerForEmail -WarningAction Ignore
}