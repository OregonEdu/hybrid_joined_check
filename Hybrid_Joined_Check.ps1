## Hybrid-Joined Check
## Benjamin Barshaw <benjamin.barshaw@ode.oregon.gov> - IT Operations & Support Network Team Lead - Oregon Department of Education
#
#  Requirements: Microsoft.Graph.Identity.DirectoryManagement PowerShell Module
#                Being connected to Microsoft Graph (Connect-MgGraph)  
#
#  This script checks to see if a computer is "Managed" using the Get-MgDevice cmdlet. I was looking for a method to check on hybrid-joined status for workstations with some form of automation as dsregcmd.exe doesn't have functionality
#  for remote workstations. I began cross-comparing return values of Get-MgDevice and came across the "IsManaged" property. This method can be adapted to not only cycle through Active Directory, but rather check status on EVERY 
#  workstation returned by Get-MgDevice regardless of which tenant/agency it is part of.

# Default amount of days to go back is a week this is changeable by running the script as such: .\Hybrid_Joined_Check.ps1 -DaysBack 50 (or any number of days you wish to go back)
param(
    [int]$DaysBack = 7
)

# Class for our report
class hybridReport
{
    [string]$Workstation
    [string]$DateJoined
    [string]$HybridStatus
}

# User-defined variables for e-mailing the report
$emailAddressToSendReportTo = "<CHANGE_TO_EMAIL_ADDRESS>" # Example: Benjamin.Barshaw@ode.oregon.gov
$emailAddressToSendReportFrom = "<CHANGE_TO_SENDER>" # Example: ODE Hybrid-Joined Report <no-reply@ode.oregon.gov>
$dateForEmail = Get-Date -Format MM/dd/yyyy # Doesn't need touching
$emailSubject = "<CHANGE_TO_SUBJECT>" # Example: ODE Hybrid-Joined Report - $($dateForEmail)
$smtpServerForEmail = "<CHANGE_TO_MAILSERVER>" # Example: smtp.agencyname.oregon.gov

# CSS styling for the e-mail report
$cssStyle = @"
<style>
body{font-family:Calibri;font-size:12pt;}
table{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse; padding-right:5px}
th{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:black;background-color:#FFFFFF }
th{border-width: 1px;padding: 5px;border-style: solid;border-color: black}
td{border-width: 1px;padding: 5px;border-style: solid;border-color: black}
</style>
"@

# Variables for our dates
$startDate = (Get-Date).AddDays(-$DaysBack)
$startDateForEmail = Get-Date -Date $startDate -Format MM/dd/yyyy
$endDate = Get-Date

# Get list of AD computers that were joined in between our date ranges specified -- again, this could be removed entirely if we wanted to check on devices returned by Get-MgDevice
$getComputers = Get-ADComputer -Filter '(whenCreated -gt $startDate) -and (whenCreated -lt $endDate)' -Properties whenCreated
# Count of how many computers were joined
$getCount = $getComputers.Count

# If any computers are returned, begin forming our e-mail report
If ($getCount -gt 0)
{
    $emailArray = @()
}

Write-Host -ForegroundColor Cyan "Found $($getCount) computers domain-joined in the last $($DaysBack) days. Checking hybrid-joined status..."

# Cycle through every computer object returned from our Get-ADComputer query
ForEach ($domainPC in $getComputers)
{
    # Create and start populating our hybridReport object with data
    $getDate = Get-Date -Date $domainPC.whenCreated -Format "MM/dd/yyyy"
    $exportMe = [hybridReport]::new()
    $exportMe.Workstation = [string]$domainPC.Name
    $exportMe.DateJoined = [string]$getDate    

    # The meat of script -- perform the check to see if it managed
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

    # Add the hybridReport object to an array
    $emailArray += $exportMe
}

# E-mail the report if specified
Write-Host -ForegroundColor Cyan "E-mail report?"
$yesNo = Read-Host -Prompt "[Y/N]"
If ($yesNo -eq "y")
{
    $hybridHeader = "<H2>Workstations Joined to ODE Domain From $($stateDateForEmail)-$($dateForEmail) Hybrid-Joined Status - Count: $($getCount)</H2>"
    $generateEmail = $emailArray | ConvertTo-Html -Head $cssStyle -Body $hybridHeader -Title "ODE Hybrid-Joined Report"
    Send-MailMessage -To $emailAddressToSendReportTo -From $emailAddressToSendReportFrom -Subject $emailSubject -BodyAsHtml ($generateEmail | Out-String) -SmtpServer $smtpServerForEmail -WarningAction Ignore
}