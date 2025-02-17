param($name)
if(!(test-path "$psscriptroot/$name")){
	write-host "cant find $name"
}


function merge {
	param($infolder,$outfile)
	$filecount = Get-ChildItem $infolder | measure 

	if($filecount.count -eq 0){
		write-error "no files"
		return
	}

	$fileEntries = @()
	if(!(test-path "$infolder/init.mp4")){
		write-error "missing init.mp4 in $infolder"
		return
	}
	$fileEntries += "$infolder/init.mp4"

	for($i=1;$i -lt $filecount.count; $i++) {
		if(!(test-path "$infolder/seg-$i.m4s")){
			write-error "missing seg-$i.m4s in $infolder"
			return
		}
		$fileentries += "$infolder/seg-$i.m4s"
	}
	$outputstream = [System.IO.File]::Open($outfile,[System.IO.FileMode]::Append)
	foreach( $file in $fileEntries )
	{
		write-host -nonewline -separator " " "`r" $file
		$data = [System.IO.File]::ReadAllBytes($file)
		$outputstream.Write( $data, 0, $data.length )
	}
	$outputstream.Close()
}


merge -infolder "$psscriptroot/$name/video" -outfile "$psscriptroot/$name/video.mp4"
merge -infolder "$psscriptroot/$name/audio" -outfile "$psscriptroot/$name/audio.mp4"

write-host "`nremux video"
ffmpeg -i "$psscriptroot/$name/video.mp4" -c copy "$psscriptroot/$name/video-remux.mp4"
rm "$psscriptroot/$name/video.mp4"

write-host "remux audio"
ffmpeg -i "$psscriptroot/$name/audio.mp4" -c copy "$psscriptroot/$name/audio-remux.mp4"
rm "$psscriptroot/$name/audio.mp4"

write-host "combining into $name.mp4"
ffmpeg -i "$psscriptroot/$name/video-remux.mp4" -i "$psscriptroot/$name/audio-remux.mp4" -c copy "$name.mp4"
rm "$psscriptroot/$name/audio-remux.mp4"
rm "$psscriptroot/$name/video-remux.mp4"

write-host "file created, checking for errors"

ffmpeg -v error -i "$name.mp4" -f null - 2>"$Psscriptroot/error-$name.log"