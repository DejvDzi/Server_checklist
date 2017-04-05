# Date format for email subject
$date=            Get-Date -format "yyyy_MM_dd"
# SMTP server ip
$smtpip=          "1.2.3.4"
# Email subject
$sub=             "Checklista MDT dla serwera "+$env:COMPUTERNAME+" z dnia "+$date+""

# Activation status
$aktywacja=       Get-Registration $env:COMPUTERNAME
# Firewall service status
$firewall=        get-service MpsSvc | Select -ExpandProperty status 
# Waiter service status
$waiter=          get-service Waiter | Select -ExpandProperty status 
# NTP server
$ntp=             ((w32tm /query /configuration | ? {$_ -match 'ntpserver:'}) -split " ")[1].substring(0)
# ShadowCopy status
$shadow=          Get-WMIObject Win32_ShadowStorage | Select-Object  @{n=’GB’;e={[math]::Round([double]$_.MaxSpace/1GB,3)}} | select -ExpandProperty GB
# IIS status
$iis=             Get-Websitestate | Select-object -ExpandProperty value
# Show domain users in local group Administrators
$local_admins=    net localgroup Administrators | ? {$_ -match 'EC'} 
# Check region settings
$region=          Get-culture | select -ExpandProperty displayname
# Check NIC Teaming
$nic=             Get-NetLbfoTeam | select -ExpandProperty name
# Get SNMP IP
$snmp_ip=        (Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers -Name 1).1
# Get SNMP Community group
$snmp_community=  Get-Item -Path HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities | select-object -ExpandProperty Property
# Get idle session time
[string]$min =    ((net config server |? {$_ -match '(min)'}) -split " ")[18].substring(0)
# Get Eset service status
$ekrn=            Get-Service ekrn | select -ExpandProperty status
# Get windows update status
$updt=            Get-Service wuauserv | select -ExpandProperty status
# Show user permissions for specified shared directory
$mapowanie =      cacls d:eurocash | ? {$_ -match $env:COMPUTERNAME}
# Get status for waiter task
$waiter_schedule= Get-ScheduledTask | ? {$_ -match 'waiter'} | Select-Object -ExpandProperty State
# Get status for cliner task
$log_clean=       Get-ScheduledTask | ? {$_ -match 'czyszczenie'} | Select-Object -ExpandProperty State
# Get filezilla server status
$filezilla=       Get-Service "FileZilla Server" | select -ExpandProperty status
# Show IP
$localip=         Get-NetIPAddress | ? AddressFamily -eq IPv4 | ? InterfaceAlias -like "local*" | Select-object -ExpandProperty IPAddress




#Uncheck "Automatically Detect Settings"
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections'
$data = (Get-ItemProperty -Path $key -Name DefaultConnectionSettings).DefaultConnectionSettings
$data[8] = 1 # change 8th segment in GER_BINARY to 01
Set-ItemProperty -Path $key -Name DefaultConnectionSettings -Value $data
# End 

# How long deployment was running.. Math [Current time - system installlation time] 
$a= Get-Date -format HH:mm
$b= gcim Win32_OperatingSystem | select InstallDate | Select-Object -ExpandProperty InstallDate 
$c= [DateTime]$a-[DateTime]$b  
$d= ($c).TotalMinutes
# End 

# Check if system is up to date 
$srch = "Type='software' and IsAssigned=1 and IsHidden=0 and IsInstalled=0"
$searcher = (New-Object -COM Microsoft.Update.Session ).CreateUpdateSearcher() 
$updates  = $searcher.Search($srch).Updates 
if ($updates.Count -ne 0) {
  $upd = "Do zainstalowania są aktualizacje" # Updates waiting
} else {
  $upd = "System jest aktualny" # Up to date
}
# End 

# Check windows update settings
$WUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings
    if ($WUSettings.NotificationLevel -eq 0){$WU= "Nie skonfigurowano"} # To configure
ElseIf ($WUSettings.NotificationLevel -eq 1){$WU= "Wyłączone"} # off
ElseIf ($WUSettings.NotificationLevel -eq 2){$WU= "Pytaj przed pobraniem"} # Ask before download
ElseIf ($WUSettings.NotificationLevel -eq 3){$WU= "Pytaj przed instalacją"} # Ask before install
ElseIf ($WUSettings.NotificationLevel -eq 4){$WU= "Zaplanowana instalacja"} # Scheduled installation
# End 

# Check if remote desktop connection is enabled
$rdp1=(Get-ItemProperty -Path "HKLM:\system\currentControlSet\Control\Terminal Server"-Name AllowTSConnections).AllowTSConnections
$rdp2=(Get-ItemProperty -Path "HKLM:\system\currentControlSet\Control\Terminal Server"-Name fDenyTSConnections).fDenyTSConnections
if ($rdp1 -eq 1 -and $rdp2 -eq 0){$rdpstat="OK"}
Else{$rdpstat="Sprawdź ustawienia"}
# End 

# Check if remote Internet Explorer Enhanced Security Configuration is enabled
$ie1=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name IsInstalled).IsInstalled # For admin should be 0
$ie2=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name IsInstalled).IsInstalled # For user should be 1
if ($ie1 -eq 0 -and $ie2 -eq 1){$ieesc="OK"}
Else{$ieesc="Sprawdź ustawienia"}
# End

# Check system ativation status
$licenseStatus=@{0="Nielicencjonowany"; 1="Aktywowany"; 2="Out Of Box"; 3="Out Of Tolerance"; 
                 4="NonGenuineGrace"; 5="Popup Aktywuj"; 6="ExtendedGrace"} 
Function Get-Registration 

{ Param ($server="." ) 
  get-wmiObject -query  "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey <> null
                        AND ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f'
                        AND LicenseIsAddon=False" -Computername $server | 
       foreach {"{1}" -f $_.name , $licenseStatus[[int]$_.LicenseStatus] } 
}
# End

#Email body


$body_html="<!DOCTYPE html><html lang='pl'><head>`n"
$body_html+="<meta content='text/html; charset=utf8' http-equiv='Content-Type' />`n"
$body_html+="<style type='text/css'>table { width: 750px; border-collapse: collapse; margin:1px auto;}"
$body_html+="tr:nth-of-type(odd) { background: #eee;}"
$body_html+="th { background: #3498db; color: white; font-weight: bold; }"
$body_html+="td, th { padding: 10px; border: 1px solid #ccc; text-align: left; font-size: 18px;}}"
$body_html+=".central { text-align: center;}</style>"
$body_html+="</head>"
$body_html+="<body>"
$body_html+="<center><h3>Checklista MDT dla serwera $env:COMPUTERNAME ($localip), stawiany ($d) min</h3>"
$body_html+="<table><thead>"
$body_html+="<tr><th style='width: 291px; height:9px'>Usługa</th><th>Status</th></tr>"
$body_html+="</thead><tbody>"
$body_html+="<tr><td style='width: 291px; height:9px'>Status firewalla:(Stopped)</td><td> $firewall </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Status waitera:(Running)</td><td> $waiter </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>RDP:(OK)</td><td> $rdpstat </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>IIE ESC:(OK)</td><td> $ieesc </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Status IIS:(Started)</td><td> $iis </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Task czyszczenie logów:(Ready)</td><td> $log_clean </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Task waiter Schedule:(Ready)</td><td> $waiter_schedule </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Serwer NTP:(ntp.pl)</td><td> $ntp </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Windows Update:(aktualny)</td><td> $upd </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Grupy lokalnych adminów: (EC\GRP_IT_CC_Server_Admins)</td><td> $local_admins </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Locsvr:(D:\svr)</td><td> $env:locsvr</td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Nrhurt:(numer_hurtowni)</td><td> $env:nrhurt</td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Region:(Poland)</td><td> $region </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>NIC_team:(local lub local_team)</td><td> $nic </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>SNMP IP:(xx.xx.xx.xx)</td><td> $snmp_ip </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>SNMP Community:(hurtownia_cc)</td><td> $snmp_community </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Czas bezczynności:(5)</td><td> $min </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Status ESET:(Running)</td><td> $ekrn </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Status Win update:(Off)</td><td> $WU </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Status Filezilla:(Running)</td><td> $filezilla </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Maksymalny rozmiar ShadowCopy:(50gb)</td><td> $shadow GB </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Mapowanie:(D:\Ec i mapowanie)</td><td> $mapowanie </td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Status licencji windows:(Aktywowany)</td><td> $aktywacja </td></tr>"
$body_html+="</tbody></table></center>"
$body_html+="<center><table><tbody>"
$body_html+="<tr><th style='width: 291px; height:9px'>Do zrobienia</th></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Dodaj hasła do portalu <a href='http://hasla'>hasla</a></td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Ustaw IP dla karty teamingowej</td></tr>"
$body_html+="<tr><td style='width: 291px; height:9px'>Przenieś serwer do OU Servers</td></tr>"
$body_html+="</tbody></table></center></body></html>"

# End

# Save as html file
Set-Content "d:\checklista_$date.html" $body_html 
# End

# Send Email
send-mailmessage -from "Dejv MDT <Mail@from.pl>" -to "DejvDzi <xxx@to.pl>" -Encoding ([System.Text.Encoding]::UTF8) -subject $sub -body $body_html -BodyAsHtml -dno onSuccess, onFailure -smtpServer $smtpip
