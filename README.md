# Hybrid-Joined Check
Benjamin Barshaw <benjamin.barshaw@ode.oregon.gov> - IT Operations & Support Network Team Lead - Oregon Department of Education

Requirements: Microsoft.Graph.Identity.DirectoryManagement PowerShell Module
              Being connected to Microsoft Graph (Connect-MgGraph)  

This script checks to see if a computer is "Managed" using the Get-MgDevice cmdlet. I was looking for a method to check on hybrid-joined status for workstations with some form of automation as dsregcmd.exe doesn't have functionality
for remote workstations. I began cross-comparing return values of Get-MgDevice and came across the "IsManaged" property. This method can be adapted to not only cycle through Active Directory, but rather check status on EVERY 
workstation returned by Get-MgDevice regardless of which tenant/agency it is part of.
