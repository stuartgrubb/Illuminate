# Illuminate - Reveal summoner names in champ select.
# v1.0.0 - 30/04/2023

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

    # Base64 encoded icon
    $IconBase64 = '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'
    $IconBytes = [Convert]::FromBase64String($IconBase64)

    # Initialize a Memory stream containing the icon bytes
    $Stream = [System.IO.MemoryStream]::new($IconBytes, 0, $IconBytes.Length)
    $Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($Stream).GetHIcon()))


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

    # Dispose of the stream and form when finished
    $Form.Dispose()   
    $Stream.Dispose()
    
}




GUI



# Convert to exe 
#Invoke-ps2exe .\Illuminate.ps1 .\Illuminate.exe -NoConsole -iconFile .\Icon.ico -version '1.0.0'
