<#
.Synopsis
	Downloads and concatenates the files in a playlist.
.Parameter href
	The location of the target playlist. Commonly found as the src argument of the video tag.
.Parameter entry
	The entry in the playlist to download. Usually there are several entries in a playlist, each a different quality. Default is to download the first entry.
#>

param(
	[parameter(mandatory=$true)]
	[string]$href,
	[parameter(mandatory=$false)]
	[string]$output = "file.bin",
	[parameter(mandatory=$false)]
	[int]$entry = 1
)
$baseFolder = (split-path $MyInvocation.MyCommand.Path )

function getTmpFolderName
{
	param( [string]$file )
	$enc = [System.Text.Encoding]::UTF8.GetBytes( $file )
	$cr = (New-Object System.Security.Cryptography.MD5CryptoServiceProvider)
	$bytes = $cr.ComputeHash( $enc )
	return [string]::Format( "{0:X2}{1:X2}{2:X2}{3:X2}", $bytes[0],$bytes[1],$bytes[2],$bytes[3] )
}

function getFromPlaylist
{
	param( [string]$file )
	$basepath = $href.Substring(0,$href.LastIndexOf("/")+1)
	$tmpfile = $baseFolder + '\tmp2ee8'
	if(test-path -Path $tmpfile) {
		remove-item $tmpfile
	}
	(New-Object System.Net.WebClient).DownloadFile($file, $tmpfile )
	Get-Content $tmpfile | Foreach-Object {
		if( ! $_.StartsWith("#") ) {
			return $_
		}
	}
	remove-item $tmpfile
}

function getPlaylist
{
	param( [string]$playlisthref )
	$tmpfile = $baseFolder + '\tmp3938'
	if(test-path -Path $tmpfile) {
		remove-item $tmpfile
	}

	(New-Object System.Net.WebClient).DownloadFile($playlisthref, $tmpfile )
	Get-Content $tmpfile | Foreach-Object {
		if( ! $_.StartsWith("#") ) {
			if( $entry -eq 1 ) {
				$_
			}
			$entry = $entry - 1
		}
	}
	remove-item $tmpfile
}


try
{
	write-host "Parsing playlists..."
	$p = getPlaylist $href
	$list = getFromPlaylist $p
	

	$outhash = getTmpFolderName $p
	$tmpdir = $baseFolder + '\tmp' + $outhash

	if( !(test-path -Path $tmpdir) )
	{
		New-Item $tmpdir -type directory | Out-Null
	}

	write-host "Downloading files..."
	$counter = 1
	foreach($l in $list)
	{
		$tmpfile = $tmpdir + "\tmp_f" + $counter
		if( !(test-path -Path $tmpfile))
		{
			write-host -nonewline -separator " " "`r" $counter "of" $list.length 
			(New-Object System.Net.WebClient).DownloadFile($l, $tmpfile )
		}
		$counter = $counter + 1
	}
	
	write-host "`rMerging files..."
	$fileEntries = Get-ChildItem $tmpdir | sort-object lastwritetime
	$outputstream = [System.IO.File]::Open($baseFolder + "\" + $outfile,[System.IO.FileMode]::Append)
	foreach( $file in $fileEntries )
	{
		write-host -nonewline -separator " " "`r" $file
		$data = [System.IO.File]::ReadAllBytes($file.FullName)
		$outputstream.Write( $data, 0, $data.length )
	}
	$outputstream.Close()

	write-host "`rCleaning temp files..."
	remove-item $tmpdir -recurse
	write-host "Done."
}
catch
{
	$error[0]
}