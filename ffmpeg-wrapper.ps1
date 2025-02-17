param($infile,$codec,$crf)


$validCodecs = @(
	"none",
	"libx265",
	"libx264"
)
if(!$validCodecs.Contains($codec)){
	throw "valid codecs are [$($validcodecs -join ",")]"
}

$infileobj = get-item (resolve-path $infile)
if($codec -eq "none"){
	$outname = $infileobj.basename + "-remux.mp4"
	write-host "no codec selected, remuix file as $outname"
	$outfile = join-path $infileobj.directory.fullname $outname
	ffmpeg -i $infileobj.fullname -c copy $outfile
	return
}
if($crf -eq "" -or $crf -eq $null){
	throw "crf needs to be numerical, [0-51] (23 default for 264, 28 default for 265)"
}
$crfnum = [int]$crf
if($crfnum -le 0 -or $crf -gt 51){
	throw "crf needs to be numerical, [0-51] (23 default for 264, 28 default for 265)"
}
if($crfnum -le 16){
	write-warning "crf below 16 is abnormally low"
}
if($crfnum -gt 30){
	write-warning "crf above 16 is abnormally high"
}
$outname = $infileobj.basename + "-$codec-crf$crfnum.mp4"
write-host "compressing file as $outname"
$outfile = join-path $infileobj.directory.fullname $outname

ffmpeg -i $infileobj.fullname -c:a copy -vcodec $codec -crf $crfnum $outfile