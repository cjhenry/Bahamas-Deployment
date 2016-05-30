
# Simple Push DSC Config for testing

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

configuration MyConfig  {
    
    Import-DscResource -Module SYSTEMHOSTING
    Import-DscResource -ModuleName xStorage
    #Import-DscResource xPSDesiredStateConfiguration # not sure if this is needed
    Import-DscResource -Module cISCSI
    
    
    node mgt-log1 {
       
       WindowsFeature WindowsMPIO {
       Ensure = "Absent"
       Name = "Multipath-IO"
       }
                
       File DSCFolder {
           Ensure = "Present"
           DestinationPath = "c:\_MANAGED_By_DSC4"
           Type = "Directory"
        }

#region # take disk 2 online and format
        xWaitforDisk Disk7
        {
             DiskNumber = 7
             RetryIntervalSec = 60
             RetryCount = 2
        }
        xDisk GVolume
        {
             DiskNumber = 7
             DriveLetter = 'G'
             #FSLabel = 'DataDrive2'
             #AllocationunitSize = '64'
             #DependsOn = [xWaitForDisk]
        }
        
#endregion

<#
#region #MPIO

        # A module for configuring MPIO settings, fx. retry and timeout values.
        # This module requires the MPIO WindowsFeature.
        # To get the current MPIO settings, run the following command:
        #   Get-MPIOSetting
        # All changes to MPIO settings require a reboot before taking effect.
        # The settings, as listed, are the default values on a Windows Server 2012 R2 installation.

        cMPIOSetting mpioSetting {
            EnforceDefaults = $true
            PathVerificationState = 'Disabled'
            PathVerificationPeriod = 40
            PDORemovePeriod = 30
            RetryCount = 3
            RetryInterval = 5
            UseCustomPathRecovery = 'Disabled'
            CustomPathRecovery = 50
        } 
#endregion MPIO  # MPIO# MPIO

#region #NetAdapter       # Enables or disables an interface based on its InterfaceAlias property. Not much else to it.

        cNetAdapter EnableNIC1 {
            InterfaceAlias = 'Internal1'
            Enabled        = $true
        }
        cNetAdapter EnableNIC2 {
            InterfaceAlias = 'Host Management'
            Enabled        = $true
        }
         cNetAdapterName NameNIC1 {
            MACAddress             = '00-15-5D-1F-2B-49'
            InterfaceAlias         = 'Internal1'
            
        }
        cNetAdapterName NameNIC2 {
            MACAddress             = '00-15-5D-1F-2B-32'
            InterfaceAlias         = 'Host Management'
        }
  #endregion # Net Adapters

#region iSCSCi   

        # Step 1 Start the iSCSCi Initiator service
        Service iSCSiService
        {
            Name = 'MSiSCSI'
            StartupType = 'Disabled'
            State = 'stopped'
        }
        
        # Step 2 wait for the iSCSi target service to be available (optional)
        <#WaitForAny WaitForiSCSITargetServer
        {
            ResourceName = "[ciSCSIServerTarget]ClusterServerTarget"
            NodeName = 'SoFS1'
            RetryIntervalSec = 30
            RetryCount = 30
            DependsOn = "[Service]iSCSIService"
        }
        
        # Step 3 - Connect the issci initiator to the iscsi target and optionally regestier it with the iSNS Server
        ciSCSIInitiator iSCSIInitiator
        {
            #Ensure = 'Present'
            nodeaddress = 'iqn.1991-05.com.microsoft:mgt-dsc1-filecluster-target'
            TargetPortalAddress = '10.100.10.12'  
            #InitiatorPortalAddress = 'IP Address'
            IsPersistent = $true
            #iSNSServer  = 'isns1.domainname.com'
            #DependsOn = "[WaitforAny]WaitForiSCSIServerTarget"
         } # End iSCSITarget Resource
 #endregion             
 #>
    } # End Node Data
} # End Config Data

MyConfig -OutputPath "C:\_MANAGED_By_DSC"

Start-DscConfiguration -ComputerName mgt-log1 -Path "C:\_MANAGED_By_DSC" -Verbose -force

Get-DscLocalConfigurationManager
Get-DscResource -Name xDisk  -Syntax
Get-DscResource

Install-Module -Name xStorage
 


Get-MPIOSetting
Get-netadapter
Get-NetAdapter | select Name,MacAddress
Get-NetAdapter -InterfaceAlias 'Internal1' | Get-NetAdapterBinding | Format-Table DisplayName, ComponentID, Enabled



unblock-file "C:\Windows\system32\WindowsPowerShell\v1.0\Modules\SystemHosting\DscResources\SHT_NetAdapter\SHT_NetAdapter.psm1"
unblock-file "C:\Windows\system32\WindowsPowerShell\v1.0\Modules\SystemHosting\DscResources\SHT_NetAdapterName\SHT_NetAdapterName.psm1"





# Set local LCM to push mode with $guid as Config ID

Configuration ConfigurationForPull{ 
    Node mgt-log1
    {
        LocalConfigurationManager 
        { 
            ConfigurationID = "$guid"
            RefreshMode = "PUSH";
            AllowModuleOverwrite = $true;
            RebootNodeIfNeeded = $true;
            # CertificateID = "8d22a93a2a0ce629e7218a84463ceca80c3e"
            ConfigurationMode = "ApplyAndAutoCorrect";
            
        }
    } 
}  
 
ConfigurationForPull -OutputPath "$Env:Temp\PullDSCCfg"
Set-DscLocalConfigurationManager -Path "$Env:Temp\PullDSCCfg"


# 
Get-DscLocalConfigurationManager