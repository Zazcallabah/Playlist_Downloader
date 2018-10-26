Add-Type -AssemblyName System.Web
Add-Type -path ".\HtmlAgilityPack.dll"

$starturi = "https://v1.escapistmagazine.com/videos/view/loadingreadyrun/9974-LoadingReadyRumble-2-Last-Episode"

function Decode {
	param ($hash, $key)
	$c = "";
	$f = "";
	$h = "";
	while( $c.length -lt $key.length / 2 ){
		$c += $hash
	}
	$c = $c.substring(0, $key.length / 2);
	for ($a = 0; $a -lt $key.length; $a += 2)
	{
		$f += [char]([convert]::ToInt16($key[$a] + $key[$a + 1], 16));
	}
	for ($a = 0; $a -lt $c.length; $a++)
	{
		$h += [char]([int]$c[$a] -bxor [int]$f[$a]);
	}
	$h | convertfrom-json
};


function DownloadVideo
{
	param($video_uri,[switch]$forward)
	$page = Invoke-Webrequest -uri $video_uri
	$html = New-Object HtmlAgilityPack.HtmlDocument
	$html.LoadHtml($page.Content)
	$playerobject = $html.DocumentNode.SelectNodes("//*[@id=""video_player_object""]")
	$videodatatext = $playerobject.innertext
	$videodatajson = $videodatatext.Substring(14,$videodatatext.length-16) | ConvertFrom-Json
	$propertynames = $videodatajson | gm | ?{ $_.membertype -eq "NoteProperty" } | %{ $_.name }
	$parameters = $propertynames | %{ "$($_)=$($videodatajson.""$_"")".replace(";","") }
	$hash = $videodatajson.hash
	$uri = "http://www.escapistmagazine.com/videos/vidconfig.php?$($parameters -join ""&"")"
	$videokey = Invoke-Webrequest -uri $uri | select -expandproperty Content
	$date = [datetime]($html.DocumentNode.SelectNodes("//*[@class=""publish_time""]") | select -expandproperty innertext)
	$category = $html.DocumentNode.SelectNodes("//*[@class=""headline""]").ChildNodes[0].innertext -replace "[<>\\/:""|?* &]",""
	$title = $html.DocumentNode.SelectNodes("//*[@class=""headline""]").ChildNodes[1].innertext -replace "[<>\\/:""|?* &]",""
	$decoded = Decode -hash $hash -key $videokey
	$uri = $decoded.files.videos[2].src
	$filename = "$($category)-$($date.ToString(""yyyyMMdd""))-$($title).mp4"
	$result = Invoke-Webrequest -uri $uri -OutFile $filename
	
	$chain_id = if($forward){ "//*[@id=""video_next""]" } else { "//*[@id=""video_prev""]" }
	
	$chained_uri = $html.DocumentNode.SelectNodes($chain_id).attributes | ?{ $_.name -eq "href"} | select -expandproperty value
	return $chained_uri
}

$uri = $starturi
while(![string]::isNullOrWhiteSpace($uri))
{
	sleep 1
	$result = DownloadVideo -video_uri $uri
	write-host $result
	$uri = $result
	sleep 5
}
