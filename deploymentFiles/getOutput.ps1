#robocopy /v /e c:\programdata\GuestConfig\Configuration\windowsfirewallenabled\modules\ 'c:\program files\windowspowershell\modules'
#$get = invoke-dscresource -Name gcinspec -Method get -ModuleName gcinspec -Property @{name='windowsfirewallenabled';version='4.3.2.1'} -verbose
#$get
#$get.reasons
#Get-Content c:\ProgramData\GuestConfig\debug.log
Get-Content C:\ProgramData\GuestConfig\Configuration\windowsfirewallenabled\Modules\windowsfirewallenabled\windowsfirewallenabled.cli