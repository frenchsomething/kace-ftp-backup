##KACE-FTP-BACKUP
Powershell Script for Offloading [Dell/KACE K1000](http://software.dell.com/products/kace-k1000-systems-management-appliance/ "KACE K1000 Product Page") Backups via FTP.

This has been designed for KACE OS 6.4 only. 6.3 and prior utilized a different method of backup that will not be recognized by this script.

##What does it do?
KACE K1000 Backups are accessible via a FTP share on the KACE server. This script downloads those backups to a user-defined location for redundancy and to reduce space requirements on the K1000 server.
* User can define number of daily backups that are retained on backup location.
* Destination is checked for sufficient free space prior to each file download
* Daily Incremental backups are downloaded and any dependent base backups are also downloaded.
* Existing downloaded backups are checked and not re-downloaded if they are present with matching filesize
* Existing downloads with mismatched filesizes are deleted and re-downloaded

##Instructions
0. Clone the file OffloadKACEBackupsFTP.ps1 to a designated location on your local system
0. Edit the parameters (Defined below) on your local script
0. Add a task in the Windows 'Task Scheduler' with the action as outlined in the `Usage` section below, set to run daily at the approximate time your backups generally complete (The script will wait a maximum of 2 hours for the backup to complete)


##Parameters
####These parameters must be personalized in the script before running:
$BackupLocation = **"\\server.address.or.ip\FolderShare\"** *#Destination for backups to be downloaded to (Can also be a local path)*

$ServerPath = **"kace.domain.com"** *#Your KACE Server Address*

$FTPUser = **"kbftp"** *#User for KACE FTP server (Can only be kbftp)*

$FTPPass = **"getbxf"** *#Password for KACE FTP server (getbxf is default, but can be changed at `Settings>Security Settings>New FTP user password`*

$DaystoRetain = **30** *#Days of backups to retain on the desitnation location. Backups older than 30 days will be automatically deleted.*


$EmailUser = **"domain\username"** *#Username for email account to send error emails from (Recommend using service account)*

$EmailFrom = **"serviceaccount@domain.com"** *#Email address for the selected account*

$EmailPass = ConvertTo-SecureString **"P@Ssw0rD"** -AsPlainText -Force *#Password for email account for sending error emails*

$EmailTo = **"serveradmin@domain.com"** *#Email which will recieve error emails*

$PSEmailServer = **"smtp.domain.com"** *#SMTP server for sending error emails*

##Usage
```powershell
powershell -file OffloadKACEBackupsFTP.ps1
```
