control 'WindowsFirewallEnabled' do
  impact 1.0
  title 'Windows Firewall Enabled'
  desc 'Validates that the registry key is present indicating that the public profile in Windows Firewall is enabled'

  script = <<-EOH
  Get-NetFirewallProfile -Name 'Public' | ForEach-Object {$_.Enabled}
  EOH

  describe powershell(script) do
    its('stdout') { should eq "True\r\n" }
    its('stderr') { should eq '' }
  end
end
