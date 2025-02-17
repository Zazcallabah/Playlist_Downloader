param($harfile,$name,[switch]$force,[switch]$dryrun)

filter FromBase64 {
	[System.Convert]::FromBase64String( $_ )
}
function savebinary {
	param($binary,$type,$name)
	$path = "$basefolder/$type/$name"

	if($dryrun){
		write-host "fake wrote file $path"
	}

	$objtype=$binary.getType().name
	if($objtype -eq "Byte[]" ){
		[System.IO.File]::WriteAllBytes($path,$binary)
		return
	}
	if($objtype -eq "Object[]" ){
		write-warning "unexpected content response $name ($($objtype))"
		[System.IO.File]::WriteAllBytes($path,$binary)
		return
	}
	if($objtype -eq "String"){
		write-error "unexpected content response $name ($($objtype))"
		$binary | set-content -encoding utf8 "$basefolder/error-$name.json"
		return
	}

	write-error "unexpected content response $name ($($objtype))"
#	$binary | set-content -encoding utf8 "$basefolder/error-$name.json"
	return

}
function parsem3uline {
	param($line)
	if(!$line.startswith("#")){
		return new-object psobject -property @{"Identifier"=$line}
	}
	
	$col = $line.indexof(":")
	if($col -eq -1){
		return new-object psobject -property @{"Identifier"=$line.substring(1)}
	}
	$tt = $line.substring(1,$col-1)
	$o = new-object psobject
	$o | add-member -membertype noteproperty -name Identifier -value $tt

	if($tt.length+2 -ge $line.length){
		return $o
	}


	$tail = $line.substring($tt.length+2)
	if(!$tail.contains(",")){
		$o | add-member -membertype noteproperty -name Value -value $tail
		return $o
	}
	$tail -split "," | %{
		$p = $_.indexof("=")
		if($p -eq -1){
			$n = $_
			$v = ""
		} else {
			$n = $_.substring(0,$p)
			$v = $_.substring($p+1)
		}
		$o | add-member -membertype noteproperty -name $n -value $v
	}

	return $o
}
function dl {
	param($base,$type,$name)
	$headers = @{
		"Accept"="*/*";
		"Accept-Encoding"="gzip, deflate, br";
		"Accept-Language"="en-US,en;q=0.5";
		"Connection"="keep-alive";
		"Host"="starlight.nebula.tv";
		"Origin"="https://nebula.tv";
		"Referer"="https://nebula.tv/";
		"Sec-Fetch-Dest"="empty";
		"Sec-Fetch-Mode"="cors";
		"Sec-Fetch-Site"="same-site";
		"TE"="trailers";
	}
	$ua = "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/125.0"
	$uri = "$base/$name"
	if($dryrun){
		write-host "download $uri"
	} else {
		$result = Invoke-Webrequest -HttpVersion 2 -Headers $headers -UserAgent $ua -Uri $uri -SkipHttpErrorCheck
		if($result.statuscode -ne 200){
			write-error "failed at downloading $name"
			$result | convertto-json -depth 4 | set-conteknt -encoding utf8 "$basefolder/error-$name.json"
		} elseif($result.content -eq $null -or $result.content.length -eq 0) {
			write-error "$name gave empty response"
			$result | convertto-json -depth 4 | set-content -encoding utf8 "$basefolder/error-$name.json"
		} else {
			savebinary -binary $result.content -type $type -name $name
		}
	}
}

function get-entry {
	param($entries,$tail)
	$result = $entries | ?{ $_.request.url.endswith($tail) } | Select-Object -first 1
	if( $null -eq $result ){
		throw "could not find entry with url ending in $tail"
	}
	return $result
}
if(!(test-path $harfile)){
	throw "cant find file at $harfile"
}
if(!(test-path "$PSScriptroot/$name")){
	mkdir "$PSScriptroot/$name"
}
$basefolder =  "$PSScriptroot/$name"
if(!(test-path "$basefolder/video")){
	mkdir "$basefolder/video"
}
if(!(test-path "$basefolder/audio")){
	mkdir "$basefolder/audio"
}
$harcontent = Get-content -encoding utf8 $harfile |convertfrom-json -depth 99
$entries = @($harcontent.log.entries)
[Array]::Reverse($entries)


$main = $entries | ?{ $_.request.url.endswith(".m3u8") -and $_.request.url.contains("/avc_vp9") -and $_.response.status -eq 200 } | select -first 1
if($null -eq $main){
	throw "could not find main m3u list"
}


$videostreamselect = ""
$audiostreamselect = ""

$defaultaudio = "audio/und/mp4a.40.2"
$defaultvideo = "video/avc1/1"

$lines = $main.response.content.text -split "`n"
$lines | out-host
for($i=0;$i -lt $lines.length;$i++){
	if($lines[$i].startswith("#")){
		$data = parsem3uline $lines[$i]
		if($data.Identifier -eq "EXT-X-STREAM-INF"){
			$uri = $lines[$i+1]
		write-host "stream: $($data.resolution) - $($data.codecs) at path: $($uri)"
		if($data.resolution.startswith("1920x") -and $uri.endswith("/media.m3u8")){
			$cutpoint = $uri.length-("/media.m3u8".length)
			$videouri = $uri.substring(0,$cutpoint)
			if($videouri -eq $defaultvideo){
				$videostreamselect = $videouri
			} elseif($force){
				write-host "using $videouri for video"
				$videostreamselect = $videouri
			} else {
				write-warning "use -force to use '$videouri' for video"
				write-host "    (default: $defaultvideo)"
			}
		}
	}
		if($data.Identifier -eq "EXT-X-MEDIA" -and $data.type -eq "AUDIO"){
			$uri = $data.uri.trim("""")
			write-host "audio: $uri"
			if($uri.endswith("/media.m3u8")){
				$cutpoint = $uri.length-("/media.m3u8".length)
				$audiouri = $uri.substring(0,$cutpoint)
				if($audiouri -eq $defaultaudio){
					$audiostreamselect = $audiouri
				} elseif($force){
					write-host "using $audiouri for audio"
					$audiostreamselect = $audiouri
				} else {
					write-warning "use -force to use '$audiouri' for audio"
					write-host "    (default: $defaultaudio)"
				}
			}
		}
	}
}

if($videostreamselect -eq ""){
	throw "could not find expected video stream codec"
}
if($audiostreamselect -eq ""){
	throw "could not find expected audio stream codec"
}
write-host
$cut = $main.request.url.indexof("/avc_vp9")
$baseurl = $main.request.url.substring(0,$cut)
write-host "using base url:`n$baseurl"

$videoinit = get-entry -entries $entries -tail "/$videostreamselect/init.mp4"
savebinary -binary ($videoinit.response.content.text | frombase64) -type video -name init.mp4
$audioinit = get-entry -entries $entries -tail "/$audiostreamselect/init.mp4"
savebinary -binary ($audioinit.response.content.text | frombase64) -type audio -name init.mp4

$vpl =  get-entry -entries $entries -tail "/$videostreamselect/media.m3u8"
$apl =  get-entry -entries $entries -tail "/$audiostreamselect/media.m3u8"

$video_playlist = ($vpl.response.content.text -split "`r`n") | ?{ !$_.startswith("#") -and $_ -ne "" }
$audio_playlist = ($apl.response.content.text -split "`r`n") | ?{ !$_.startswith("#") -and $_ -ne "" }
write-host "video segments: " $video_playlist.length
write-host "audio segments: " $audio_playlist.length
$runcount = [math]::max($video_playlist.length,$audio_playlist.length)


for($i=0;$i -lt $runcount;$i++){

	if($null -ne $video_playlist[$i]){
		dl -base "$baseurl/$videostreamselect"-type video -name $video_playlist[$i]
	}
	if($null -ne $audio_playlist[$i]){
		dl -base "$baseurl/$audiostreamselect"-type audio -name $audio_playlist[$i]
	}
	sleep 3
}

