[Cmdletbinding()]
Param
(
    [Parameter( ParameterSetName="ODTConfigFileName")] 
    [string]$ODTConfigFileName
)

try
{
    Expand-Archive -Path $env:SystemRoot\InteractiveVMWorkingDir\OfficeWVDGalleryImageFiles\OfficeWVDGalleryImageFiles.zip -DestinationPath $env:SystemRoot\InteractiveVMWorkingDir\officeInstaller -Verbose

    #parsing html
    $HttpContent = Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117' -UseBasicParsing
    if($HttpContent.StatusCode -ne 200) 
    { 
	    throw "Office Installation script failed to find Office deployment tool link -- Response $($Response.StatusCode) ($($Response.StatusDescription))"
    }

    $response = $HttpContent.Links | Where-Object {$_.href -like "https://download.microsoft.com/download*"}

    $link = $response[0].href

    #download office deployment tool
    $ODTResponse = Invoke-WebRequest -Uri "$link" -UseBasicParsing -UseDefaultCredentials -OutFile $env:SystemRoot\InteractiveVMWorkingDir\officeInstaller\officedeploymenttool.exe -PassThru
    if($ODTResponse.StatusCode -ne 200) 
    { 
	    throw "Office Installation script failed to download Office deployment tool -- Response $($ODTResponse.StatusCode) ($($ODTResponse.StatusDescription))"
    }

    # extract the ODT's folder
    Start-Process -File "$env:SystemRoot\InteractiveVMWorkingDir\officeInstaller\officedeploymenttool.exe" -ArgumentList "/extract:$env:SystemRoot\InteractiveVMWorkingDir\officeInstaller /passive /quiet" -Wait -NoNewWindow -PassThru

    #download OneDrive.exe
    $OneDriveResponse = Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?LinkID=844652' -UseBasicParsing -UseDefaultCredentials -OutFile $env:SystemRoot\InteractiveVMWorkingDir\officeInstaller\OneDriveSetup.exe -PassThru
    if($OneDriveResponse.StatusCode -ne 200) 
    { 
	    throw "Office Installation script failed to download OneDriveSetup.exe -- Response $($OneDriveResponse.StatusCode) ($($OneDriveResponse.StatusDescription))"
    }


    Write-Host "Successfully downloaded office dependencies."
    Write-Host "Start to install office."

    # starting Office installation
    if($ODTConfigFileName)
    {
        Write-Host "ODTConfigFileName : $($ODTConfigFileName)"
        cmd.exe /c "C:\Windows\InteractiveVMWorkingDir\officeInstaller\OfficeWVDGalleryPrep.bat $($ODTConfigFileName)"
    }else
    {
        Write-Host "ODTConfigFileName : InstallOffice.xml"
        cmd.exe /c 'C:\Windows\InteractiveVMWorkingDir\officeInstaller\OfficeWVDGalleryPrep.bat'
    }
}
catch
{
		$PSCmdlet.ThrowTerminatingError($PSitem)
}

