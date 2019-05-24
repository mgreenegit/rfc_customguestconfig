#robocopy /v /e c:\programdata\GuestConfig\Configuration\windowsfirewallenabled\modules\ 'c:\program files\windowspowershell\modules'
#$get = invoke-dscresource -Name gcinspec -Method get -ModuleName gcinspec -Property @{name='windowsfirewallenabled';version='4.3.2.1'} -verbose
#$get
#$get.reasons
#Get-Content c:\ProgramData\GuestConfig\debug.log
#write-host 'Convert'
#Get-Content c:\ProgramData\GuestConfig\debugConvert.log
#write-host 'Convert0'
#Get-Content c:\ProgramData\GuestConfig\debugConvert0.log
#write-host 'Return'
#Get-Content c:\ProgramData\GuestConfig\debugReturn.log
write-host 'ReturnReasons'
Get-Content c:\ProgramData\GuestConfig\debugReturnReasons.log

