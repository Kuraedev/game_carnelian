# Converts numbered indexed-BMP sprite rips into transparent PNGs on a uniform, bottom-center
# aligned canvas, then emits a Godot SpriteFrames .tres referencing them.
#
# Usage:  powershell -File tools/convert_sprites.ps1 -MapPath sprite_maps/bridget.json
#
# The map JSON defines: name, source dir, filename prefix, key color [R,G,B], and an "anims"
# table of { start, end, fps, loop } frame ranges. Re-run after editing ranges to regenerate.

param(
    [Parameter(Mandatory = $true)][string]$MapPath
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$proj = "c:\Users\karlc\Documents\anim-proj"
$map = Get-Content (Join-Path $proj $MapPath) -Raw | ConvertFrom-Json

$srcDir = Join-Path $proj $map.source
$frames = Get-ChildItem -Path $srcDir -Filter "$($map.prefix)*.bmp" | Sort-Object Name
$keyR = $map.key[0]; $keyG = $map.key[1]; $keyB = $map.key[2]

# --- collect every frame index referenced, compute a single shared canvas size ---
$used = @{}
foreach ($name in $map.anims.PSObject.Properties.Name) {
    $a = $map.anims.$name
    for ($i = $a.start; $i -le $a.end; $i++) { $used[$i] = $true }
}
$maxW = 0; $maxH = 0
foreach ($i in $used.Keys) {
    $img = [System.Drawing.Image]::FromFile($frames[$i].FullName)
    if ($img.Width -gt $maxW) { $maxW = $img.Width }
    if ($img.Height -gt $maxH) { $maxH = $img.Height }
    $img.Dispose()
}
# pad a little so neighbouring frames never clip
$maxW += 8; $maxH += 8
Write-Output "Canvas: ${maxW}x${maxH} (frames used: $($used.Count))"

function Convert-Frame($srcPath, $outPath) {
    $src = New-Object System.Drawing.Bitmap $srcPath
    $canvas = New-Object System.Drawing.Bitmap $maxW, $maxH
    # transparent background
    for ($y = 0; $y -lt $maxH; $y++) { for ($x = 0; $x -lt $maxW; $x++) { $canvas.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0)) } }
    $offX = [int](($maxW - $src.Width) / 2)
    $offY = $maxH - $src.Height        # bottom align (feet near canvas bottom)
    for ($y = 0; $y -lt $src.Height; $y++) {
        for ($x = 0; $x -lt $src.Width; $x++) {
            $p = $src.GetPixel($x, $y)
            if ($p.R -ge ($keyR - 12) -and $p.R -le 255 -and $p.G -le ($keyG + 14) -and [Math]::Abs($p.B - $keyB) -le 14 -and $p.R -gt 200 -and $p.B -gt 200 -and $p.G -lt 30) {
                continue  # key color -> stay transparent
            }
            $canvas.SetPixel($offX + $x, $offY + $y, $p)
        }
    }
    $canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $src.Dispose(); $canvas.Dispose()
}

$charDir = Join-Path $proj ("Assets/CharAsset/" + $map.name)
# Build the SpriteFrames .tres text as we go.
$ext = New-Object System.Text.StringBuilder
$anims = New-Object System.Text.StringBuilder
$id = 0

foreach ($name in $map.anims.PSObject.Properties.Name) {
    $a = $map.anims.$name
    $animDir = Join-Path $charDir $name
    New-Item -ItemType Directory -Force -Path $animDir | Out-Null
    $frameEntries = @()
    $local = 0
    for ($i = $a.start; $i -le $a.end; $i++) {
        $outName = ("{0}_{1:D2}.png" -f $name, $local)
        $outPath = Join-Path $animDir $outName
        Convert-Frame $frames[$i].FullName $outPath
        $id++
        $resPath = "res://Assets/CharAsset/$($map.name)/$name/$outName"
        [void]$ext.AppendLine("[ext_resource type=`"Texture2D`" path=`"$resPath`" id=`"$id`"]")
        $frameEntries += "{`n`"duration`": 1.0,`n`"texture`": ExtResource(`"$id`")`n}"
        $local++
    }
    $loopStr = if ($a.loop) { "true" } else { "false" }
    $framesJoined = $frameEntries -join ", "
    [void]$anims.AppendLine("{")
    [void]$anims.AppendLine("`"frames`": [$framesJoined],")
    [void]$anims.AppendLine("`"loop`": $loopStr,")
    [void]$anims.AppendLine("`"name`": &`"$name`",")
    [void]$anims.AppendLine("`"speed`": $($a.fps).0")
    [void]$anims.AppendLine("}, ")
    Write-Output ("  {0}: frames {1}-{2} ({3})" -f $name, $a.start, $a.end, ($a.end - $a.start + 1))
}

$tres = "[gd_resource type=`"SpriteFrames`" load_steps=$($id + 1) format=3 uid=`"uid://frames_$($map.name)`"]`n`n"
$tres += $ext.ToString() + "`n"
$tres += "[resource]`n"
$tres += "animations = [" + $anims.ToString() + "]`n"
$tresPath = Join-Path $charDir ($map.name + "_frames.tres")
Set-Content -Path $tresPath -Value $tres -Encoding UTF8
Write-Output "Wrote $tresPath"
