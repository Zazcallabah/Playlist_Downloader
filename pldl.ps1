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
	[int]$entry = 1
)
write-host "Parsing playlists..."

function getFromPlaylist
{
	param( [string]$file )
	$basepath = $href.Substring(0,$href.LastIndexOf("/")+1)
	$tmpfile = 'tmp2ee8'
	if(test-path -Path $tmpfile)
	{
		remove-item $tmpfile
	}

	(New-Object System.Net.WebClient).DownloadFile($basepath+$file, $tmpfile )
	Get-Content $tmpfile | Foreach-Object {
		if( ! $_.StartsWith("#") )
		{
			return $basepath+$_
		}
	}

	remove-item $tmpfile
}

function getPlaylist
{
	$tmpfile = 'tmp3938'
	if(test-path -Path $tmpfile)
	{
		remove-item $tmpfile
	}

	(New-Object System.Net.WebClient).DownloadFile($href, $tmpfile )

	Get-Content $tmpfile | Foreach-Object {
		if( ! $_.StartsWith("#") )
		{
			if( $entry -eq 1 )
			{
				$_
			}
			$entry = $entry - 1
		}
	}
	remove-item $tmpfile
}
try{
$p = getPlaylist
$list = getFromPlaylist $p

$tmpdir = "tmp39e"
if( !(test-path -Path $tmpdir) )
{
	New-Item $tmpdir -type directory | Out-Null
}
$outfile = $p.Substring(0, $p.LastIndexOf(".") ) + ".ts"

$counter = 0;
while( test-path -Path $outfile )
{
	$outfile = $p.Substring(0, $p.LastIndexOf(".") ) + "_" + $counter + ".ts"
	$counter = $counter + 1
}

sc -Path $outfile -value $null
$counter = 1
write-host "Downloading files..."
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
$outputstream = [System.IO.File]::Open($outfile,[System.IO.FileMode]::Append)
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
}catch{
$error[0]
}