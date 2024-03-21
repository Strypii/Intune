<# 
.SYNOPSIS 
Make Windows devices trigger Intune's automatic enrolment process.
 
.DESCRIPTION 
For a device to enrol itself, the user must be part of the auto-enrolment group.
https://intune.microsoft.com/#view/Microsoft_AAD_IAM/UpdateMdmAppBlade/objectId/1d97c85a-91f1-414f-9ab9-05877bcca6fb/appId/0000000a-0000-0000-c000-000000000000/appDisplayName/Microsoft%20Intune/isOnPrem~/false

This script with return with either one of two return codes. If your RMM tool can handle return codes, use this for monitoring success/failure.

    0 = Success
    1001 = Failure
 
.NOTES     
        Name       : Intune Automatic Enrolment
        Author     : Dan Harris  
        Version    : 1.0.0  
        DateCreated: 21.03.2024
        Blog       : https://inforcer.com/       
#>

$key = 'SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\*'

# Get full tenant ID string from system registry
# E.G, HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx
try {
    $keyinfo = Get-Item "HKLM:\$key"
}
catch {
    Write-Host "Tenant ID is not found!"
    exit 1001
}

# Convert $keyinfo to tenant ID (get the last part for xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx)
# Then sanitise the registry key to fit Windows' standards
$registryPath = $keyinfo.name
$tenantID = $registryPath.Split("\")[-1]
$path = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\$tenantID"

# Check if reg key exists
if(!(Test-Path $path)) {
    Write-Host "KEY $path not found!"
    exit 1001
} else {
    try {
        # Check if URLs exist. Will throw an error (go to catch) if not.
        Get-ItemProperty $path -Name MdmEnrollmentUrl
    }
    catch {
        # If URLs don't exist, add them to registry
        Write-Host "MDM Enrollment registry keys not found. Registering now..."
        New-ItemProperty -LiteralPath $path -Name 'MdmEnrollmentUrl' -Value 'https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc' -PropertyType String -Force -ea SilentlyContinue;
        New-ItemProperty -LiteralPath $path -Name 'MdmTermsOfUseUrl' -Value 'https://portal.manage.microsoft.com/TermsofUse.aspx' -PropertyType String -Force -ea SilentlyContinue;
        New-ItemProperty -LiteralPath $path -Name 'MdmComplianceUrl' -Value 'https://portal.manage.microsoft.com/?portalAction=Compliance' -PropertyType String -Force -ea SilentlyContinue;
    }
    finally {
        # Trigger AutoEnroll with the deviceenroller
        try {
            C:\Windows\system32\deviceenroller.exe /c /AutoEnrollMDM
            Write-Host "Device is performing the MDM enrollment!"
            exit 0
        }
        catch {
            Write-Host "Something went wrong (C:\Windows\system32\deviceenroller.exe)"
            exit 1001          
        }

    }
}
exit 0
