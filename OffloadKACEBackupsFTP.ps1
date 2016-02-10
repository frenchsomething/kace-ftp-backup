$BackupLocation = "\\server.address.or.ip\FolderShare\" #Destination for backups to be downloaded to (Can also be a local path)
$ServerPath = "kace.domain.com" #Your KACE Server Address
$FTPUser = "kbftp" #User for KACE FTP server (Can only be kbftp)
$FTPPass = "getbxf" #Password for KACE FTP server (getbxf is default, but can be changed at Settings>Security Settings>New FTP user password
$DaystoRetain = 30 #Days of backups to retain on the desitnation location. Backups older than 30 days will be automatically deleted.

$EmailUser = "domain\username" #Username for email account to send error emails from (Recommend using service account)
$EmailFrom = "serviceaccount@domain.com" #Email address for the selected account
$EmailPass = ConvertTo-SecureString "P@Ssw0rD" -AsPlainText -Force #Password for email account for sending error emails
$EmailTo = "serveradmin@domain.com" #Email which will recieve error emails
$PSEmailServer = "smtp.domain.com" #SMTP server for sending error emails


$cred = new-object -typename System.Management.Automation.PSCredential `
         -argumentlist $EmailUser, $EmailPass

function Write-Logline ($String){"[ "+(Get-Date).ToString()+" ]	"+$String | Out-File $LogfilePath -encoding ASCII -append}
function Write-Logline-Blank (){"" | Out-Filee $LogfilePath -encoding ASCII -append}
function Get-FTPModDate ($Source,$UserName,$Password) 
{ 
	# Create a FTPWebRequest object to handle the connection to the ftp server 
    $ftprequest = [System.Net.FtpWebRequest]::create($Source) 
    # set the request's network credentials for an authenticated connection 
    $ftprequest.Credentials = 
        New-Object System.Net.NetworkCredential($username,$password) 
    $ftprequest.Method = [System.Net.WebRequestMethods+Ftp]::GetDateTimestamp 
    $ftprequest.UseBinary = $true 
    $ftprequest.KeepAlive = $false 
     
	try
		{
			# send the ftp request to the server 
			$ftpresponse = $ftprequest.GetResponse()
			$ModDate = $ftpresponse.LastModified.Date
			$today = Get-Date -displayhint date
			$DateDiff = New-TimeSpan $ModDate $today
			If($DateDiff.Days -lt 1){
				$Status = "Backup is Still Running. Pausing for 15 minutes..."
			}
			Else {
				$Status = "Backup File present, but it is from previous day. BACKUP PROCESS LIKELY STUCK. Pausing for 15 minutes..."
			}

			$ftpresponse.Close()
		}
		catch [System.Net.WebException]
		{
			#Write-Logline $_.Exception.ToString()
			$Status = "Y"
		}
    Return $Status 
}
function Get-FTPDirList ($Source,$UserName,$Password) 
{ 
	# Create a FTPWebRequest object to handle the connection to the ftp server 
    $ftprequest = [System.Net.FtpWebRequest]::create($Source) 
    # set the request's network credentials for an authenticated connection 
    $ftprequest.Credentials = 
        New-Object System.Net.NetworkCredential($username,$password) 
    $ftprequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory 
    $ftprequest.UseBinary = $true 
    $ftprequest.KeepAlive = $false
	# send the ftp request to the server 
	$ftpresponse = $ftprequest.GetResponse()
	$stream = $ftpresponse.GetResponseStream()
	$buffer = new-object System.Byte[] 1024 
	$encoding = new-object System.Text.AsciiEncoding 

	$outputBuffer = "" 
	$foundMore = $false 

	## Read all the data available from the stream, writing it to the 
	## output buffer when done. 
	do 
	{ 
		## Allow data to buffer for a bit 
		start-sleep -m 1000 

		## Read what data is available 
		$foundmore = $false 
		$stream.ReadTimeout = 500

		do 
		{ 
			try 
			{ 
				$read = $stream.Read($buffer, 0, 1024) 

				if($read -gt 0) 
				{ 
					$foundmore = $true 
					$outputBuffer += ($encoding.GetString($buffer, 0, $read))
				} 
			} catch { $foundMore = $false; $read = 0 } 
		} while($read -gt 0) 
	} while($foundmore)

	$ftpresponse.Close()
	Return $outputBuffer
	
}
function Get-FTPFilesize ($DestFolder,$ServerPath,$Filename,$UserName,$Password) 
{ 
	$destfilepath = $DestFolder+$Filename
	$Source = "ftp://"+$ServerPath+"/"+$Filename
	If((Test-Path $destfilepath) -eq $true) {
		# Create a FTPWebRequest object to handle the connection to the ftp server 
		$ftprequest = [System.Net.FtpWebRequest]::create($Source) 
		 
		# set the request's network credentials for an authenticated connection 
		$ftprequest.Credentials = 
			New-Object System.Net.NetworkCredential($username,$password) 
		 
		$ftprequest.Method = [System.Net.WebRequestMethods+Ftp]::GetFileSize 
		$ftprequest.UseBinary = $true 
		$ftprequest.KeepAlive = $false 
		 
		# send the ftp request to the server 
		$ftpresponse = $ftprequest.GetResponse() 

		$SourceSize = $ftpresponse.ContentLength
		$ftpresponse.Close()

		$destfile = Get-Item $destfilepath
		If ($SourceSize -eq $destfile.length) {
			#Destination file is present and sizes match, which is a pretty good indication that the transfer was successful.
			Return $true
		}
		Else {
			#Destination file is present, but sizes don't match. This must be a failed or corrupt transfer, so we'll have to delete and retry.
			$SourceSizeGB = [string] ([math]::round($SourceSize/1024/1024/1024,2))
			$SourceSize = [string] $SourceSize
			Write-Logline "$Filename is present on backup location, but sizes don't match. Deleting failed transfer."
			Write-Logline "Size of [$Filename] to download: $SourceSizeGB GB ($SourceSize bytes)"
			Remove-Item $destfile
			Return $false
		}
	}
	Else {
		#Destination File not yet present
		$SourceSizeGB = [string] ([math]::round($SourceSize/1024/1024/1024,2))
		$SourceSize = [string] $SourceSize
		Write-Logline "Size of [$Filename] to download: $SourceSizeGB GB ($SourceSize bytes)"
		Return $false
	}
}

function Get-FTPFile ($DestFolder,$ServerPath,$Filename,$UserName,$Password) 
    { 
    $target = $DestFolder+$Filename
	$Source = "ftp://"+$ServerPath+"/"+$Filename
    # Create a FTPWebRequest object to handle the connection to the ftp server 
    $ftprequest = [System.Net.FtpWebRequest]::create($Source) 
     
    # set the request's network credentials for an authenticated connection 
    $ftprequest.Credentials = 
        New-Object System.Net.NetworkCredential($username,$password) 
     
    $ftprequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile 
    $ftprequest.UseBinary = $true 
    $ftprequest.KeepAlive = $false 
     
    # send the ftp request to the server 
    $ftpresponse = $ftprequest.GetResponse() 
     
    # get a download stream from the server response 
    $responsestream = $ftpresponse.GetResponseStream() 
     
    # create the target file on the local system and the download buffer 
    $targetfile = New-Object IO.FileStream ($Target,[IO.FileMode]::Create) 
    [byte[]]$readbuffer = New-Object byte[] 1024 
     
    # loop through the download stream and send the data to the target file 
    do{ 
        $readlength = $responsestream.Read($readbuffer,0,1024) 
        $targetfile.Write($readbuffer,0,$readlength) 
    } 
    while ($readlength -ne 0) 
     
    $targetfile.close() 
    }
	
function Send-Error-Email ($ErrorText) {
	Write-Logline "$ErrCt error(s) were encountered. Sending Error email."
	$LogContents = [IO.File]::ReadAllText($LogfilePath)
	$LogContentsHTML = $LogContents -Replace "`n", "</br>"
	$Body = "Hello KACE Team,</br><h3>The backup process for server <font color=""blue"">$ServerPath</font> encountered an error.</h3></br><h4>Error text:</h4>$ErrorText</br></br><h4>Full Logs:</h4>$LogContentsHTML</br></br>"
	#$Body += $LogContents
	$Subjectvar = "Backup Log, Error Count: $ErrCt"
	$Subject = [string] $Subjectvar
	Send-MailMessage -To $EmailTo -from $EmailFrom -Subject $Subject -BodyAsHtml $Body -Port 587 -Priority: High
}
	
function Goto-Error-Exit ($ErrorString) {
	Write-Logline "Encountered Fatal Error. Sending Error Email and exiting."
	Write-Logline $ErrorString
	Send-Error-Email $ErrorString
	exit 1
}

#-------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------
#-----------------------------------MAIN STARTS HERE----------------------------------
#-------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------

If ($BackupLocation.substring(0,2) -eq "\\") [
	#Backup Location is a UNC Path
	}

$ErrCt = 0
$CurDir = Split-Path $MyInvocation.MyCommand.Path
$CurDate = (get-date).tostring("yyyyMMdd")
$CurTime = (get-date).tostring("HHmmss")

$LogsPath = $CurDir + "\Logs\"
$LogfileName = $CurDate + "_backuplog.txt"
if ( -not ( Test-Path $LogsPath -PathType Container )) { 
	New-Item -Path $LogsPath -ItemType directory
}
$LogfilePath = $LogsPath + $LogfileName
$LogFileExists = Test-Path $LogfilePath
If ($LogFileExists -eq $True) {
	$LogfileName = $CurDate + "_" + $CurTime + "_backuplog.txt"
	$LogfilePath = $LogsPath + $LogfileName
}

Write-Logline "Backing up $ServerPath to $BackupLocation"

$Count=0
Do {
	$BackupComplete = Get-FTPModDate "ftp://$serverpath/BACKUP_RUNNING" $FTPUser $pass
	If ($BackupComplete -eq "Y") {
		Write-Logline "-->Onboard backup appears complete. Proceeding with offload."
		$BackupStillRunning = $false
	}
	Else {
		#Backup isn't complete, so we'll pause for 15 minutes to try and wait for it to finish. Writing the status we recieved from the Get-FTPModDate function to the log.
		Write-Logline $BackupComplete
		Start-Sleep -s 900
		$BackupStillRunning = $true
		$Count += 1
	}
} while($BackupStillRunning -and $Count -lt 8)
$Count=0
Do {
$FileList = Get-FTPDirList "ftp://$ServerPath" $FTPUser $pass
$Count+=1
} while($FileList -eq "" -and $Count -lt 2)
If($FileList -eq "") {
	$ErrCt+=1
	Goto-Error-Exit "Unable to retrieve file list from FTP server."
}
$IncrPattern = ".+_k1_incr.*"+$CurDate+".tgz"
$FileList -match $IncrPattern
$IncrFile = $matches[0]
echo "Incremental File: $IncrFile"
Write-Logline-Blank
Write-Logline "Incremental File to Download:	[$IncrFile]"
$BaseDate = $IncrFile.substring(0,8)
$BasePattern = $BaseDate+"_k1_base_.*tgz"
$FileList -match $BasePattern
$BaseFile = $matches[0]
echo "Base File: $BaseFile"
Write-Logline "Base File to Download:		[$BaseFile]"
$Count=0
#Check for (properly sized) existing Incremental File
If ($IncrFile -ne "") {
	$TestIncr = Get-FTPFilesize $BackupLocation $ServerPath $IncrFile $FTPUser $pass
	If (-not ($TestIncr)) {
		Do {
			Write-Logline "Copying $IncrFile to $BackupLocation"
			Get-FTPFile $BackupLocation $ServerPath $IncrFile $FTPUser $pass
			$TestIncr = Get-FTPFilesize $BackupLocation $ServerPath $IncrFile $FTPUser $pass
			$Count+=1
		} Until(($TestIncr) -or $Count -gt 2)
		If (-not ($TestIncr)) {
			$ErrCt+=1
			Write-Logline "Copying of Incremental file [$IncrFile] FAILED."
			$ErrorText+= "Copying of Incremental file [$IncrFile] FAILED."
		}
	}
	ELSE {
		Write-Logline "Incremental File [$IncrFile] is already present and sizes match."
	}
}
Else {
	$ErrCt+=1
	$ErrorText += "Could not identify Incremental Backup for today."
}
$Count=0
#Check for (properly sized) existing BASE File
If ($BaseFile -ne "") {
	$TestBase = Get-FTPFilesize $BackupLocation $ServerPath $BaseFile $FTPUser $pass
	If (-not ($TestBase)) {
		Do {
			Write-Logline "Copying $BaseFile to $BackupLocation"
			Get-FTPFile $BackupLocation $ServerPath $BaseFile $FTPUser $pass
			$TestBase = Get-FTPFilesize $BackupLocation $ServerPath $BaseFile $FTPUser $pass
			$Count+=1
		} Until(($TestBase) -or $Count -gt 2)
		If (-not ($TestBase)) {
			$ErrCt+=1
			Write-Logline "Copying of Base file [$BaseFile] FAILED."
			$ErrorText+= "Copying of Base file [$BaseFile] FAILED."
		}
	}
	ELSE {
		Write-Logline "Base File [$BaseFile] is already present and sizes match."
	}
}
Else {
	$ErrCt+=1
	$ErrorText += "Could not identify Base Backup for today's backup."
}
Write-Logline-Blank

#Now we delete old backups from the destination backup directory
$Subtract = "-"+$DaystoRetain
$MinDate = (Get-Date).AddDays($Subtract)
#$CurDate = (get-date).tostring("yyyyMMdd")
Get-ChildItem $BackupLocation -Filter *.tgz | `
Foreach-Object{
	$Filename = $_.Name
	If($Filename -like "*_k1_incr_*") {
		$FileDate = $Filename.substring($Filename.Length-8,2)+"/"+$Filename.substring($Filename.Length-6,2)+"/"+$Filename.substring($Filename.Length-12,4)
		$FormattedFileDate = [datetime] $FileDate
		$DateDiff = New-TimeSpan $MinDate $FormattedFileDate
		If ($DateDiff.Days -gt -1) {
			echo " File is still new enough. Keeping Incremental file dated "$Filename.substring(0,8)
			$BaseFilesKeep += $Filename.substring(0,8)+"|"
		}
		Else {
			echo "FILE IS TOO OLD. Deleting [$Filename]"
			Remove-Item $_.FullName
			$DeletedIncrFile = $true
		}
    }
	Else {
		echo "$Filename is not an incremental backup."
	}

}

Get-ChildItem $BackupLocation -Filter *.tgz | `
Foreach-Object{
	$Filename = $_.Name
	If($Filename -like "*_k1_base_*") {
		$FileDate = $Filename.substring(0,8)
		If ($BaseFilesKeep -like "*$FileDate*") {
			echo "Keeping Base File [$Filename]"
		}
		Else {
			Write-Logline "Base file no longer needed by any Incremental backups. Deleting [$Filename]"
			Remove-Item $_.FullName
			$DeletedBaseFile = $true
		}
    }
	Else {
		#Not a base backup
	}

}

If($DeletedIncrFile -ne $true -and $DeletedBaseFile -ne $true){
	Write-Logline "No old backups were found/deleted."
}
If($ErrCt -gt 0){
	Send-Error-Email $ErrorText
}

#Copy log file to network/backup share
if ( -not ( Test-Path $BackupLocation"Logs" -PathType Container )) { 
	New-Item -Path $BackupLocation"Logs" -ItemType directory
}
Copy-Item $LogfilePath $BackupLocation"Logs"

