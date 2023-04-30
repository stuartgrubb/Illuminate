# Illuminate - Reveal summoner names in champ select.
# v1.0.0 - 29/04/2023

Function ClientStatus {

    $Script:ClientStatus = $null
    $Client = $null
    $ClientPort = $null
    $ClientToken = $null
    $RiotPort = $null
    $RiotToken = $null

    # Capture client information
    $Client = Get-CimInstance -Query "Select * from Win32_Process WHERE name Like 'LeagueClientUx.exe'" | Select CommandLine

    # Capture ports and auth tokens
    IF ($Client) {

        # Capture App Port
        $Client.CommandLine -Match "--app-port=([0-9]*)" | Out-Null
        $ClientPort = $Matches[1] 

        # Capture Client Auth Token
        $Client.CommandLine -Match "--remoting-auth-token=([\w-]*)" | Out-Null
        $ClientToken = $Matches[1]

        # Capture Riot App Port
        $Client.CommandLine -Match "--riotclient-app-port=([0-9]*)" | Out-Null
        $RiotPort = $Matches[1]

        # Capture Riot Auth Token
        $Client.CommandLine -Match "--riotclient-auth-token=([\w-]*)" | Out-Null
        $RiotToken = $Matches[1]


        # Check if all ports and auth tokens have been captured then format authtokens
        IF ($ClientPort -and $ClientToken -and $RiotPort -and $RiotToken) {
            AuthTokens

        }
        Else {
        Write-Host "`nFailed to capture Client Info"
            $Script:ClientStatus = 'Failed'
            UpdateStatus
        }
    }
    # Client was not found
    ELSE {
        Write-Host "`nLeagueClientUx.exe not found"
        $Script:ClientStatus = 'Not Found'
        UpdateStatus
        If ($SummonerNames) {
            Clear-Variable -Name SummonerNames -Scope Script
        }
        ShowSummoners
    }
}




Function AuthTokens {

  # Workaround for certificate check
Add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


    # Client Token
    $Pair = "riot:" + $ClientToken

    # Turn the string into a base64 encoded string
    $Bytes = [System.Text.Encoding]::ASCII.GetBytes($Pair)
    $ClientToken = [System.Convert]::ToBase64String($Bytes)

    # Define basic authorization header containing the token
    $Script:ClientHeaders = @{
        Authorization = "Basic {0}" -f ($ClientToken)
    }

    # Riot Token
    $Pair = "riot:" + $RiotToken

    # Turn the string into a base64 encoded string
    $Bytes = [System.Text.Encoding]::ASCII.GetBytes($Pair)
    $RiotToken = [System.Convert]::ToBase64String($Bytes)

    # Define basic authorization header containing the token
    $Script:RiotHeaders = @{
        Authorization = "Basic {0}" -f ($RiotToken)
    }

    GetCurrentSummoner
}




Function GetCurrentSummoner {

    # Clear Summoner Name
    If ($CurrSummoner) {
        Clear-Variable -Name CurrSummoner -Scope Script
    }

    # Get Current Summoner Name
    $Script:CurrSummoner = Invoke-RestMethod -Uri "https://127.0.0.1:$ClientPort/lol-summoner/v1/current-summoner" -Headers $ClientHeaders | Select -ExpandProperty DisplayName

    # Get Summoner Region
    $Script:Region = Invoke-RestMethod -Uri "https://127.0.0.1:$RiotPort/riotclient/region-locale" -Headers $RiotHeaders | Select -ExpandProperty Region
    
    # Get Current Gameflow--Phase
    $Script:GameFlowPhase = Invoke-RestMethod -Uri "https://127.0.0.1:$ClientPort/lol-gameflow/v1/gameflow-phase" -Headers $ClientHeaders

    # If both current summoner and region are found, update gui status.
    IF ($CurrSummoner -and $Region) {
        $Script:ClientStatus = 'Connected' 
        UpdateStatus
    }
    Else { # Try capturing client information
        ClientStatus
    }

    GetSummonerNames
}




# PowerShell 5
Function GetSummonerNames {

    # Reset GameFlowPhase and Summoner Names
    Clear-Variable -Name GameFlowPhase -Scope Script
    $Names = New-Object System.Collections.ArrayList
    $Script:SummonerNames = New-Object System.Collections.ArrayList

    # Get Current Gameflow-Phase
    $Script:GameFlowPhase = Invoke-RestMethod -Uri "https://127.0.0.1:$ClientPort/lol-gameflow/v1/gameflow-phase" -Headers $ClientHeaders

    # Check for Gameflow-Phase
    IF ($GameFlowPhase) {
    
        # If player is in ChampSelect - Query Summoner Names 
    
        IF ($GameFlowPhase -match 'ChampSelect') {

            # Query Summoner Names
            $Participants = Invoke-RestMethod -Uri "https://127.0.0.1:$RiotPort/chat/v5/participants/champ-select" -Headers $RiotHeaders
            $Participants = $Participants.Participants.Name

            # Convert to utf8 for special chars

            ForEach ($Name in $Participants) {
                $Bytes = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($Name)
                $Name = [System.Text.Encoding]::UTF8.GetString($Bytes)
                $Names.Add($Name)
            }

            # Format Summoner Names
            IF ($Names.Count -gt 1) {

                For ($i=0; $i -le $Names.Count; $i++) {
                    # Add comma to each summoner name except for the last one
                    IF ($i -lt $Names.Count -1) {
                        $SummonerNames.Add($Names[$i] + ",")
                    }
                    Else {
                        $SummonerNames.Add($Names[$i])
                    }
                }
            }
            Else {
                $SummonerNames.Add($Names)
            }
        }
        ElseIf ($GameFlowPhase -match 'InProgress') {            
            # Match is in progress - format URLs to display the 'ingame' page.
            ShowSummoners
            SiteURLs
        }


        IF ($SummonerNames) {
            ShowSummoners
            SiteURLs
        }
        Else {
            $SummonerNames = $null
            ShowSummoners
            SiteURLs
        }

    }
    Else { 
        $SummonerNames = $null
        ShowSummoners
        SiteURLs
    }

}




Function UpdateStatus {
    
    $Label1.Text = "Client: $ClientStatus"
    $Label2.Text = "ID: $CurrSummoner"
    $Label3.Text = "Status: $GameFlowPhase"

    IF ($ClientStatus -eq 'Connected') {
        $Label1.ForeColor = '#00ff00'
    }
    Else {
        $Label1.ForeColor = '#ff0000'
        $Label2.Text = "ID:"
        $Label3.Text = "Status:"
    }

}





Function ShowSummoners {
    $OutputBox1.Text = $SummonerNames | Out-String
}




Function SiteURLs {
    
    # Region codes - Required for sites like UGG
    $RegionCodes = @{
    NA = 'na1';
    EUNE = 'eun1';
    EUW = 'euw1';
    KR = 'kr';
    BR = 'br1';
    JP = 'jp1';
    RU = 'ru';
    OCE ='oc1';
    TR = 'tr1';
    LAN = 'la1';
    LAS = 'la2';
    PH = 'ph2';
    SG = 'sg2';
    TH = 'th2';
    TW = 'tw2';
    VN = 'vn2'}

    $Summoners = $null
    $Summoners = $SummonerNames | Out-String

    # OP.GG
    IF ($Site -eq '1' -and $GameFlowPhase -match 'InProgress') {
        $URL = "https://www.op.gg/summoners/$Region/$CurrSummoner/ingame"   
        Start-Process $URL
    }    
    ElseIf ($Site -eq '1') {    
        $URL = "https://www.op.gg/multisearch/$Region`?summoners=$Summoners"
        Start-Process $URL
    }

    # U.GG
    IF ($Site -eq '2' -and $GameFlowPhase -match 'InProgress') {
        # Match region from UGG hashtable
        $UGGRegion = $RegionCodes[$Region]
        $URL = "https://u.gg/lol/profile/$UGGRegion/$CurrSummoner/live-game"
        Start-Process $URL
    }
    ElseIf ($Site -eq '2') {
        # Match region from UGG hashtable
        $UGGRegion = $RegionCodes[$Region]
        $URL = "https://u.gg/multisearch?summoners=$Summoners`&region=$UGGRegion"
        Start-Process $URL
    }

    # Porofessor
    IF ($Site -eq '3' -and $GameFlowPhase -match 'InProgress') {
        # Set Region to lowercase - Porofessor does not accept caps
        $Region = $Region.ToLower()
        $URL = "https://porofessor.gg/live/$Region/$CurrSummoner/ranked-only"
        Start-Process $URL 
    }
    ElseIf ($Site -eq '3') {
        # Set Region to lowercase - Porofessor does not accept caps
        $Region = $Region.ToLower()
        $URL = "https://porofessor.gg/pregame/$Region/$Summoners/ranked-only"
        Start-Process $URL
    }


    # Clear Site Variable
    $Site = $null

}




Function DarkMode {

    IF ($Form.BackColor -eq '#ffffff') {
        $Form.BackColor = '#000000'
        $Button1.ForeColor = '#ffffff'
        $Button2.ForeColor = '#ffffff'
        $Button3.ForeColor = '#ffffff'
        $Button4.ForeColor = '#ffffff'
        $Button5.ForeColor = '#ffffff'
        $Button6.ForeColor = '#ffffff'
        $Button3.Text = 'Light Mode'

        # Maintain green status color when switching between light/dark mode
        IF ($ClientStatus -eq 'Connected') {
            $Label1.ForeColor = '#00ff00'
        }      
        Else {      
            $Label1.ForeColor = '#ff0000'
        }
        $Label2.ForeColor = '#ffffff'
        $Label3.ForeColor = '#ffffff'       
    } 
    Else {
        $Form.BackColor = '#ffffff'
        $Button1.ForeColor = '#000000'
        $Button2.ForeColor = '#000000'
        $Button3.ForeColor = '#000000'
        $Button4.ForeColor = '#000000'
        $Button5.ForeColor = '#000000'
        $Button6.ForeColor = '#000000'
        $Button3.Text = 'Dark Mode'


        # Maintain green status color when switching between light/dark mode
        IF ($ClientStatus -eq 'Connected') {
            $Label1.ForeColor = '#00ff00'
        }
        Else {      
            $Label1.ForeColor = '#ff0000'
        }
        $Label2.ForeColor = '#000000'
        $Label3.ForeColor = '#000000'       
    }
}




Function Dodge {

    TASKKILL /f /im "LeagueClientUx.exe"

}




Function GUI {

    Add-Type -AssemblyName System.Windows.Forms

    # Declare Objects
    $FormObject = [System.Windows.Forms.Form]
    $LabelObject = [System.Windows.Forms.Label]
    $ButtonObject = [System.Windows.Forms.Button]
    $TextBox = [System.Windows.Forms.RichTextBox]
    $Icon = New-Object System.Drawing.Icon (".\Icon.ico")
    

    # Form Properties
    $Form = New-Object $FormObject
    $Form.ClientSize = '380,200'
    $Form.FormBorderStyle = 'Fixed3D'
    $Form.MaximizeBox = $false
    $Form.Icon = $Icon
    $Form.Text = 'Illuminate'
    $Form.BackColor = '#ffffff'


    # Button Properties
    $Button1 = New-Object $ButtonObject
    $Button1.Text = 'Get Summoners'
    $Button1.Width = '120'
    $Button1.Height = '28'
    $Button1.ForeColor = '#000000'
    $Button1.Font = 'Segoe UI,10,style=Bold'
    $Button1.Location = New-Object System.Drawing.Point(250,10)

    $Button2 = New-Object $ButtonObject
    $Button2.Text = 'Dodge'
    $Button2.Width = '120'
    $Button2.Height = '28'
    $Button2.ForeColor = '#000000'
    $Button2.Font = 'Segoe UI,10,style=Bold'
    $Button2.Location = New-Object System.Drawing.Point(250,160)

    $Button3 = New-Object $ButtonObject
    $Button3.Text = 'Dark Mode'
    $Button3.Width = '120'
    $Button3.Height = '28'
    $Button3.ForeColor = '#000000'
    $Button3.Font = 'Segoe UI,10,style=Bold'
    $Button3.Location = New-Object System.Drawing.Point(250,130)

    $Button4 = New-Object $ButtonObject
    $Button4.Text = 'OP.GG'
    $Button4.Width = '120'
    $Button4.Height = '28'
    $Button4.ForeColor = '#000000'
    $Button4.Font = 'Segoe UI,10,style=Bold'
    $Button4.Location = New-Object System.Drawing.Point(250,40)

    $Button5 = New-Object $ButtonObject
    $Button5.Text = 'U.GG'
    $Button5.Width = '120'
    $Button5.Height = '28'
    $Button5.ForeColor = '#000000'
    $Button5.Font = 'Segoe UI,10,style=Bold'
    $Button5.Location = New-Object System.Drawing.Point(250,70)

    $Button6 = New-Object $ButtonObject
    $Button6.Text = 'PORO'
    $Button6.Width = '120'
    $Button6.Height = '28'
    $Button6.ForeColor = '#000000'
    $Button6.Font = 'Segoe UI,10,style=Bold'
    $Button6.Location = New-Object System.Drawing.Point(250,100)


    # Text Label Properties
    $Label1 = New-Object $LabelObject
    $Label1.Text = "Client: $ClientStatus"
    $Label1.AutoSize = $true
    $Label1.Font = 'Segoe UI,12,style=Bold'
    $Label1.Location = New-Object System.Drawing.Point(10,8)

    $Label2 = New-Object $LabelObject
    $Label2.Text = "ID: $CurrSummoner"
    $Label2.AutoSize = $true
    $Label2.Font = 'Segoe UI,12,style=Bold'
    $Label2.Location = New-Object System.Drawing.Point(10,30)

    $Label3 = New-Object $LabelObject
    $Label3.Text = "Status: $SummonerStatus"
    $Label3.AutoSize = $true
    $Label3.Font = 'Segoe UI,12,style=Bold'
    $Label3.Location = New-Object System.Drawing.Point(10,52)


    # Output Box Properties
    $OutputBox1 = New-Object $TextBox
    $OutputBox1.width = '200'
    $OutputBox1.height = '110'
    $OutputBox1.Margin = 0
    $OutputBox1.Font = 'Segoe UI,11'
    $OutputBox1.Location = New-Object System.Drawing.Point(10,80)


    # Button Functions
    $Button1.Add_Click({ClientStatus})
    $Button2.Add_Click({Dodge})
    $Button3.Add_Click({DarkMode})
    $Button4.Add_Click({$Site = '1'; SiteURLs})
    $Button5.Add_Click({$Site = '2'; SiteURLs})
    $Button6.Add_Click({$Site = '3'; SiteURLS})


    # Adds Objects to Form
    $Form.Controls.AddRange(@($Label1,$Label2,$Label3,$Button1,$Button2,$Button3,$Button4,$Button5,$Button6,$OutputBox1))

    # Display Form
    $Form.ShowDialog() | Out-Null

    # Cleans up Form
    $Form.Dispose()

    
    
}




GUI



# Convert to exe 
#Invoke-ps2exe .\Illuminate.ps1 .\Illuminate.exe -NoConsole -iconFile .\Icon.ico -version '1.0.0'