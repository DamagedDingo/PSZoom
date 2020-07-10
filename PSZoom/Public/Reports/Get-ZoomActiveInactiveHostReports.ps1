<#

.SYNOPSIS
Retrieve an active or inactive host report for a specified period of time. 

.DESCRIPTION
Retrieve an active or inactive host report for a specified period of time. 
The time range for the report is limited to a month and the month should fall under the past six months.

.PARAMETER Type
Active or Inactive. Defaults to Inactive.

.PARAMETER From
Start date in 'yyyy-MM-dd' format. The default is the current day.

.PARAMETER To
End date. The default is the current day.

.PARAMETER PageSize
The number of records returned within a single API call. Default is 30.

.PARAMETER PageNumber
The current page number of returned records. Default is 1.

.PARAMETER CombineAllPages
If a report has multiple pages this will loop through all pages automatically and place all users found from each 
page into the Users field of the report generated. The page size is set automatically to 300.

.PARAMETER LastSixMonths
Use this switch to retrieve an array of the last 6 months of reports. This automatically combines users from 
each page into the Users field of each report. The page size is set automatically to 300.

.PARAMETER ApiKey
The Api Key.

.PARAMETER ApiSecret
The Api Secret.

.EXAMPLE
Get first page of inactive users in July of 2019.
Get-ZoomActiveInactiveHostReports -from '2019-07-01' -to '2019-07-31' -page 1 -pagesize 300

.EXAMPLE
Get all pages of who was inactive for today, combined into a single report
Get-ZoomActiveInactiveHostReports -CombineAllPages

.EXAMPLE
Get first page of the last 30 days of an active host report.
Get-ZoomActiveInactiveHostReports -From (Get-date).AddDays(-30) -PageSize 300 -PageNumber 1 -Type Active

.EXAMPLE
Get all pages of the last 30 days of reports.
Get-ZoomActiveInactiveHostReports -From (Get-date).AddDays(-30) -PageSize 300 -CombineAllPages

.EXAMPLE
Get an array of reports for each month of the last 6 months for active users.
Get-ZoomActiveInactiveHostReports -LastSixMonths -Type Active

.OUTPUTS
A hastable with the Zoom API response.

#>

function Get-ZoomActiveInactiveHostReports {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(
            ValueFromPipelineByPropertyName = $True,
            ParameterSetName = 'Default'
        )]
        [Parameter(
            ParameterSetName = 'CombineAllPages',
            ValueFromPipelineByPropertyName = $True
        )]
        [datetime]$From = (Get-Date),

        [Parameter(
            ParameterSetName = 'Default',
            ValueFromPipelineByPropertyName = $True
        )]
        [Parameter(
            ParameterSetName = 'CombineAllPages',
            ValueFromPipelineByPropertyName = $True
        )]
        [datetime]$To = (Get-Date),

        [Parameter(
            ParameterSetName = 'Default',
            ValueFromPipelineByPropertyName = $True
        )]
        [ValidateRange(1, 300)]
        [Alias('size', 'page_size')]
        [int]$PageSize = 30,

        [Parameter(
            ParameterSetName = 'Default',
            ValueFromPipelineByPropertyName = $True
        )]
        [Alias('page', 'page_number')]
        [int]$PageNumber = 1,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'CombineAllPages')]
        [Parameter(ParameterSetName = 'LastSixMonths')]
        [ValidateSet('active', 'inactive')]
        [string]$Type = 'inactive', #Zoom defaults to inactive

        [Parameter(ParameterSetName = 'LastSixMonths')]
        [switch]$LastSixMonths,

        [Parameter(ParameterSetName = 'CombineAllPages')]
        [switch]$CombineAllPages,

        [int]$RateLimit = 20,

        [string]$ApiKey,

        [string]$ApiSecret
    )

    begin {
        #Generate Headers and JWT (JSON Web Token)
        $Headers = New-ZoomHeaders -ApiKey $ApiKey -ApiSecret $ApiSecret
        [string]$From = $From.ToString('yyyy-MM-dd')
        [string]$To = $To.ToString('yyyy-MM-dd')
    }

    process {
        if ($PsCmdlet.ParameterSetName -eq 'Default') {
            $Request = [System.UriBuilder]"https://api.zoom.us/v2/report/users"
            $query = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)  
            $query.Add('from', $From)
            $query.Add('to', $To)
            $query.Add('page_size', $PageSize)
            $query.Add('page_number', $PageNumber)
            $query.Add('type', $Type)
            $Request.Query = $query.ToString()

            $response = Invoke-ZoomRestMethod -Uri $request.Uri -Headers $headers -Method GET
            
            Write-Output $response
        } elseif ($PsCmdlet.ParameterSetName -eq 'CombineAllPages') {
            $InitialReport = Get-ZoomActiveInactiveHostReports -From $From -To $To -PageSize 300 -PageNumber 1 -Type $Type
            $TotalPages = $InitialReport.page_count
            $CombinedReport = [PSCustomObject]@{
                From                  = $From
                To                    = $To
                Page_count            = $InitialReport.page_count
                Total_records         = $InitialReport.total_records
                Total_meetings        = $InitialReport.total_meetings
                Total_participants    = $InitialReport.total_participants
                Total_meeting_minutes = $InitialReport.total_meeting_minutes
                Users                 = $InitialReport.users
            }

            if ($TotalPages -gt 1) {
                for ($i=2; $i -le $TotalPages; $i++){
                    $users = (Get-ZoomActiveInactiveHostReports -From $From -To $To -PageSize 300 -PageNumber $i -Type $Type).users
                    $CombinedReport.Users += $users
                }
            }

            Write-Output $CombinedReport
        }  elseif ($PsCmdlet.ParameterSetName -eq 'LastSixMonths') {
            $AllReports = @()
            $monthRanges = (Get-LastSixMonthsDateRanges)

            foreach ($month in $monthRanges.keys) {
                $AllReports += (Get-ZoomActiveInactiveHostReports -From $monthRanges."$month".begin -To $monthRanges."$month".end -Pagesize 300 -Type $Type -CombineAllPages)
            }

            Write-Output $AllReports
        }
    }
}