Configuration WindowsFirewallEnabled {
    
    Import-DscResource -ModuleName 'GuestConfiguration'

    Node WindowsFirewallEnabled {
        
        Registry 'Registry HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile\EnableFirewall' {
            ValueName   = 'EnableFirewall'
            Key         = 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile'
            ValueType   = 'DWord'
            ValueData   = 1
        }
    }
}