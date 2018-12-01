#Import-Module VMware.VimAutomation.Core
$vcentername=Read-Host -Prompt "Enter Name/IP of Vcenter" 
$user= Read-Host -Prompt "Enter the username of the vCenter"
$Pass = Read-Host -Prompt "Enter the Password of the vCenter"
$location=get-location
try{
connect-viserver $vcentername -User $user -Password $Pass -ErrorAction Stop -WarningAction 0
	}
catch {  
        Write-Host "Connection Problem due to" $_
		exit
}
Write-output "Host_Name;SSH_Timeout;Shell_InterTimeout;SSH_Service;SSH_Service_Policy;Netlogon_Service;NTP_Firewall_Excep;VirtualSwitch_Name;Promiscuous;Forged;Mac_Change;SysLog;Password_History;Password_Complexity;MobStatus;List_NTP_Server" | out-file -filepath $location\output.txt
Write-output "" | out-file -filepath $location\failed_to_connect.txt
foreach($VMHost in Get-VMHost){
# Start the SSH service
Connect-VIServer $VMHost -User $user -Password $Pass -ErrorAction SilentlyContinue -ErrorVariable ConnectError | Out-Null
		if ($ConnectError) {
		Write-host "failed to connect to $VMHost...trying next host..." -foregroundcolor Yellow
		Write-output "$VMHost" | out-file -Append -filepath $location\failed_to_connect.txt
    		}
Else {
Get-VMHostService -VMHost $VMHost | Where-Object {$_.key -eq "tsm-ssh"} | Start-VMHostService  | Out-Null
$mob= Write-Output "y" | & $location\plink.exe -ssh -v -noagent $VMHost -l $user -pw $Pass "vim-cmd proxysvc/service_list | grep -w mob"
if ($mob -eq $null){$mobvalue="disabled"}
$p_history= Write-Output "y" | & $location\plink.exe -ssh -v -noagent $VMHost -l $user -pw $Pass "grep remember /etc/pam.d/passwd | awk '{print `$8}'"
$p_disabled= Write-Output "y" | & $location\plink.exe -ssh -v -noagent $VMHost -l $user -pw $Pass "grep disabled /etc/pam.d/passwd | awk '{print `$5}'"

# Stop SSH service
Get-VMHostService -VMHost $VMHost | Where-Object {$_.key -eq "tsm-ssh"} | Stop-VMHostService  -Confirm:$false | Out-Null
$SSH_Timeout = $VMHost | Get-AdvancedSetting -Name UserVars.ESXiShellTimeOut | Select -ExpandProperty Value
$SSH_shellinterTimeout = $VMHost | Get-AdvancedSetting -Name 'UserVars.ESXiShellInteractiveTimeOut' | Select -ExpandProperty Value
$SSH_Service = $VMHost | Get-VMHostService | Where-Object {($_.Key -eq "TSM-ssh")} | Select -ExpandProperty Running
$SSH_Service_Policy = $VMHost | Get-VMHostService | Where-Object {($_.Key -eq "TSM-ssh")} | Select -ExpandProperty Policy
$St_Netlon_Service = $VMHost | Get-VMHostService | Where-Object { $_.key -eq "netlogond" } | Select -ExpandProperty Running
$NTP_Firewall_Excep = $VMHost | Get-VMHostFirewallException | Where-Object {$_.Name -eq "NTP client"} | Select -ExpandProperty Enabled
$syslog=(Get-AdvancedSetting -Entity $VMHost -Name Syslog.global.logHost).value
$List_NTP_Server = $VMhost | Get-VMHostNtpServer
$vswitch=Get-VirtualSwitch -Standard -VMHost $VMHost | Get-SecurityPolicy
$vsname=$vswitch.VirtualSwitch
$prom=$vswitch.AllowPromiscuous
$Forged=$vswitch.ForgedTransmits
$Macchange=$vswitch.MacChanges
Write-output "$VMHost;$SSH_Timeout;$SSH_shellinterTimeout;$SSH_Service;$SSH_Service_Policy;$St_Netlon_Service;$NTP_Firewall_Excep;$vsname;$prom;$Forged;$Macchange;$syslog;$p_history;$p_disabled;$mobvalue;$List_NTP_Server" | out-file -Append -filepath $location\output.txt
}
}
