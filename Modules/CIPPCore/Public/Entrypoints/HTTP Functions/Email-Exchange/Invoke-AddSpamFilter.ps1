using namespace System.Net

Function Invoke-AddSpamFilter {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)


    $APIName = $Request.Params.CIPPEndpoint
    Write-LogMessage -headers $Request.Headers -API $APINAME -message 'Accessed this API' -Sev 'Debug'

    $RequestParams = $Request.Body.PowerShellCommand | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty GUID, comments
    $RequestPriority = $Request.Body.Priority

    $Tenants = ($Request.body.selectedTenants).value
    $Result = foreach ($Tenantfilter in $tenants) {
        try {
            $GraphRequest = New-ExoRequest -tenantid $Tenantfilter -cmdlet 'New-HostedContentFilterPolicy' -cmdParams $RequestParams
            $Domains = (New-ExoRequest -tenantid $Tenantfilter -cmdlet 'Get-AcceptedDomain').name
            $ruleparams = @{
                'name'                      = "$($RequestParams.name)"
                'hostedcontentfilterpolicy' = "$($RequestParams.name)"
                'recipientdomainis'         = @($domains)
                'Enabled'                   = $true
                'Priority'                  = $RequestPriority
            }
            $GraphRequest = New-ExoRequest -tenantid $Tenantfilter -cmdlet 'New-HostedContentFilterRule' -cmdParams $ruleparams
            "Successfully created spamfilter for $tenantfilter."
            Write-LogMessage -headers $Request.Headers -API $APINAME -tenant $tenantfilter -message "Created spamfilter rule for $($tenantfilter)" -sev Info
        } catch {
            "Could not create create spamfilter rule for $($tenantfilter): $($_.Exception.message)"
            Write-LogMessage -headers $Request.Headers -API $APINAME -tenant $tenantfilter -message "Could not create create spamfilter rule for $($tenantfilter): $($_.Exception.message)" -sev Error
        }
    }

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{Results = @($Result) }
        })

}
