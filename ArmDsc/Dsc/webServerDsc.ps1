Configuration Main
{
param([string] $nodeName, [string] $webDeployPackage)

# Import required modules
Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -Module xWebAdministration
Import-DSCResource -ModuleName xNetworking

Node $nodeName
  {
   # Install the IIS role 
		WindowsFeature IIS 
		{ 
			Ensure          = "Present" 
			Name            = "Web-Server" 
		} 
		# Install the ASP .NET 4.5 role 
		WindowsFeature AspNet45 
		{ 
			Ensure          = "Present" 
			Name            = "Web-Asp-Net45" 
		} 
	   
		Script DeployWebPackage
		{
			GetScript = {@{Result = "DeployWebPackage"}}
			TestScript = {$false}
			SetScript ={
				[system.io.directory]::CreateDirectory("C:\WebApp")
				$dest = "C:\WebApp\Site.zip" 
				Remove-Item -path "C:\inetpub\80" -Force -Recurse -ErrorAction SilentlyContinue
				Remove-Item -path "C:\inetpub\81" -Force -Recurse -ErrorAction SilentlyContinue
				
				Invoke-WebRequest $using:webDeployPackage -OutFile $dest

				Add-Type -assembly "system.io.compression.filesystem"
				[io.compression.zipfile]::ExtractToDirectory($dest, "C:\inetpub\80")
				[io.compression.zipfile]::ExtractToDirectory($dest, "C:\inetpub\81")
			}
			DependsOn  = "[WindowsFeature]IIS"
		}

		# Copy the website content 
		File Port80 
		{ 
			Ensure          = "Present" 
			SourcePath      = "C:\WebApp"
			DestinationPath = "C:\Inetpub\80"
			Recurse         = $true 
			Type            = "Directory" 
			DependsOn       = "[Script]DeployWebPackage" 
		}   
		# Copy the website content 
		File Port81 
		{ 
			Ensure          = "Present" 
			SourcePath      = "C:\WebApp"
			DestinationPath = "C:\Inetpub\81"
			Recurse         = $true 
			Type            = "Directory" 
			DependsOn       = "[Script]DeployWebPackage" 
		}   
		
		# Stop the default website
        xWebsite DefaultSite 
        {
            Ensure          = 'Present'
            Name            = 'Default Web Site'
            State           = 'Stopped'
            PhysicalPath    = 'C:\inetpub\wwwroot'
            DependsOn       = '[WindowsFeature]IIS'
        }
		
		# Create the new Website on port 80
        xWebsite Port80WebSite
        {
            Ensure          = "Present"
            Name            = "Port80WebSite"
            State           = "Started"
            PhysicalPath    = "C:\Inetpub\80"
            BindingInfo     = @(
                MSFT_xWebBindingInformation
                {
                    Protocol              = "HTTP"
                    Port                  = 80
                }
            )
            DependsOn       = "[File]Port80", "[xWebsite]DefaultSite"
        }

		# Create the new Website on port 81
        xWebsite Port81WebSite
        {
            Ensure          = "Present"
            Name            = "Port81WebSite"
            State           = "Started"
            PhysicalPath    = "C:\Inetpub\81"
            BindingInfo     = @(
                MSFT_xWebBindingInformation
                {
                    Protocol              = "HTTP"
                    Port                  = 81
                }
            )
            DependsOn       = "[File]Port81"
        }

		# Open Firewall rule for port 81
		xFirewall Firewall
        {
            Name                  = 'Allow Website Ports 80-81'
            DisplayName           = 'Allow Firewall rule for websites on ports 80-81'
            Ensure                = 'Present'
            Enabled               = 'True'
            Profile               = ('Domain', 'Private', 'Public')
            Direction             = 'InBound'
            RemotePort            = ('Any')
            LocalPort             = ('80', '81')
            Protocol              = 'TCP'
            Description           = 'Firewall rule for websites on ports 80-81'
        }				
	
  }
}