<#
	.SYNOPSIS
		Change the userid and  password of a service
	
	.DESCRIPTION
		This script loops thru all the Windows Servers found in AD and changes the userid and password of the service specified.
	
	.PARAMETER Service
		Name of the service being changed.
	
	.PARAMETER Account
		The new Userid to be used.
	
	.PARAMETER Password
		The new password for the service
	
	.PARAMETER LogFile
		The full path to the log file.
	
	.PARAMETER ComputerName
		Computer(s) to check
	
	.NOTES
	
		===========================================================================
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[string]
	$Service,
	[Parameter(Mandatory = $true)]
	[string]
	$Account,
	[Parameter(Mandatory = $true)]
	[string]
	$Password,
	[string]
	$LogFile = ".\Change-ServicePassword.log",
	[Parameter(ValueFromPipeline = $true)]
	[Alias('List')]
	[String[]]
	$ComputerName
)

function Write-log
{
	<#
	.SYNOPSIS
		Write to log file
	
	.DESCRIPTION
		This function writes to a log file and the console.
	
	.PARAMETER msg
		A description of the msg parameter.
	
	.NOTES
		Additional information about the function.
#>
	param
	(
		$msg
	)
	
	$datetime = Get-Date -Format "MM/dd/yyyy HH:mm:ss";
	Write-Output "$datetime : $msg" | out-file $LogFile -Append
	Write-Output "$datetime : $msg"
}
Write-log "If Computername is supplied on command line or pipeline use it"
If (!($ComputerName))
{
	Write-log 'Load Quest AD Module'
	Add-PSSnapin Quest.ActiveRoles.ADManagement -ErrorAction 'SilentlyContinue'
	
	Write-log 'Get list of Windows Server Names from AD'
	$list = (Get-QADComputer -SizeLimit 0 -IncludedProperties LastLogonTimeStamp -LDAPFilter "(operatingsystem=*Windows Server*)").Name
}
else
{
	Write-log "Using supplied computer list"
	$list = $ComputerName
}

Write-log "Processing $($list.count) servers."

Write-log "Function to check for service and change the password"
Function Set-ServiceAcctCreds([string]$ComputerName, [string]$ServiceName, [string]$newAcct, [string]$newPass)
{
	Write-log "Set the filter"
	$filter = 'Name=' + "'" + $ServiceName + "'" + ''
	
	Write-log "Get the service"
	$service = Get-WMIObject -ComputerName $ComputerName -namespace "root\cimv2" -class Win32_Service -Filter $filter
	
	Write-log "If the service exists, change the password"
	if ($service)
	{
		Write-log "Changing $newAcct password on $computername"
		$rc = $service.Change($null, $null, $null, $null, $null, $null, $newAcct, $newPass)
		if ($rc.returnvalue -ne 0)
		{
			Write-log "Error changing the login and password"
			exit
		}
		Write-log "Stop the service $ServiceName"
		$rc = $service.StopService()
		if ($rc.ReturnValue -eq '5')
		{
			Write-log "$ServiceName is already stopped on $computername"
		}
		if ($rc.ReturnValue -eq '0')
		{
			Write-log "$ServiceName has been successfully stopped on $computername"
		}
		if ($rc.ReturnValue -eq '2')
		{
			Write-log "Access has been denied to $ServiceName on $computername"
			Exit
		}
		
		Write-log "Waiting for the service $ServiceName to stop"
		while ($service.Started)
		{
			sleep 2
			$service = Get-WMIObject -ComputerName $ComputerName -namespace "root\cimv2" -class Win32_Service -Filter $filter
		}
		
		Write-log "Start the service"
		$service.StartService()
	}
}

Write-log "Loop through the list of computers"
foreach ($computername in $list)
{
	Write-log "Checking $computername"
	Set-ServiceAcctCreds -ComputerName $computername -ServiceName $Service -newAcct $Account -newPass $Password
}
Write-log "Done."


