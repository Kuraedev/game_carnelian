# Converts numbered indexed-BMP sprite rips into transparent PNGs on a uniform, bottom-center
# aligned canvas, then emits a Godot SpriteFrames .tres referencing them.
#
# Usage:  powershell -File tools/convert_sprites.ps1 -MapPath sprite_maps/ky.json
#
# Map JSON:
#   { name, source, prefix, key:[R,G,B], key_mode:"color"|"flood", key_tol:<int>,
#     anims:{ <name>:{ ranges:[[a,b],...], fps, loop } } }
#   - "color" mode: every pixel matching the key (within key_tol) becomes transparent.
#       Best when the key color never appears inside the sprite (e.g. magenta).
#   - "flood" mode: only key-colored pixels connected to the image border are removed.
#       Best when the key color also appears inside the sprite as outlines (e.g. black).
#   - "ranges" lets one animation span multiple frame segments (e.g. idle [[0,7],[19,30]]).

param(
    [Parameter(Mandatory = $true)][string]$MapPath
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$proj = "c:\Users\karlc\Documents\anim-proj"
$map = Get-Content (Join-Path $proj $MapPath) -Raw | ConvertFrom-Json

$srcDir = Join-Path $proj $map.source
$allFrames = Get-ChildItem -Path $srcDir -Filter "$($map.prefix)*.bmp" | Sort-Object Name
$keyR = [int]$map.key[0]; $keyG = [int]$map.key[1]; $keyB = [int]$map.key[2]
$keyMode = if ($map.PSObject.Properties.Name -contains "key_mode") { $map.key_mode } else { "color" }
$keyTol = if ($map.PSObject.Properties.Name -contains "key_tol") { [int]$map.key_tol } else { 24 }
$tol2 = $keyTol * $keyTol
$keyColor = [System.Drawing.Color]::FromArgb($keyR, $keyG, $keyB)

function Expand-Ranges($a) {
    # A range [x, y] expands ascending; [y, x] (y > x) expands descending so an animation
    # can play frames in reverse (e.g. a there-and-back dodge: [[81,84],[84,81]]).
    $list = New-Object System.Collections.Generic.List[int]
    foreach ($r in $a.ranges) {
        $lo = [int]$r[0]; $hi = [int]$r[1]
        if ($lo -le $hi) {
            for ($i = $lo; $i -le $hi; $i++) { $list.Add($i) }
        } else {
            for ($i = $lo; $i -ge $hi; $i--) { $list.Add($i) }
        }
    }
    return $list
}

# Map frame NUMBER (parsed from filename) -> file, so ranges are by filename number and
# tolerate gaps in the numbering (e.g. melee jumps 0..43 with a few missing).
$frameByNum = @{}
foreach ($f in $allFrames) {
    if ($f.BaseName -match '(\d+)$') { $frameByNum[[int]$matches[1]] = $f }
}

# shared canvas size across every referenced frame
$used = @{}
foreach ($name in $map.anims.PSObject.Properties.Name) {
    foreach ($i in (Expand-Ranges $map.anims.$name)) { $used[$i] = $true }
}
$maxW = 0; $maxH = 0
foreach ($i in $used.Keys) {
    if (-not $frameByNum.ContainsKey($i)) { continue }
    $img = [System.Drawing.Image]::FromFile($frameByNum[$i].FullName)
    if ($img.Width -gt $maxW) { $maxW = $img.Width }
    if ($img.Height -gt $maxH) { $maxH = $img.Height }
    $img.Dispose()
}
$maxW += 8; $maxH += 8
Write-Output "Canvas: ${maxW}x${maxH}  frames=$($used.Count)  key=$keyR,$keyG,$keyB mode=$keyMode tol=$keyTol"

function To32bpp($raw) {
    $b = New-Object System.Drawing.Bitmap $raw.Width, $raw.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.DrawImage($raw, 0, 0, $raw.Width, $raw.Height)
    $g.Dispose()
    return $b
}

# Remove background-connected key pixels via border flood fill (preserves interior outlines).
function Flood-Key($src) {
    $w = $src.Width; $h = $src.Height
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $d = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $d.Stride
    $buf = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $buf, 0, $buf.Length)
    $removed = New-Object bool[] ($w * $h)
    $q = New-Object 'System.Collections.Generic.Queue[int]'
    $seeds = New-Object System.Collections.Generic.List[int]
    for ($x = 0; $x -lt $w; $x++) { $seeds.Add($x); $seeds.Add(($h - 1) * $w + $x) }
    for ($y = 0; $y -lt $h; $y++) { $seeds.Add($y * $w); $seeds.Add($y * $w + ($w - 1)) }
    foreach ($p in $seeds) {
        if ($removed[$p]) { continue }
        $px = $p % $w; $py = [int][math]::Floor($p / $w); $idx = $py * $stride + $px * 4
        $dr = $buf[$idx + 2] - $keyR; $dg = $buf[$idx + 1] - $keyG; $db = $buf[$idx] - $keyB
        if (($dr * $dr + $dg * $dg + $db * $db) -le $tol2) { $removed[$p] = $true; $buf[$idx + 3] = 0; $q.Enqueue($p) }
    }
    while ($q.Count -gt 0) {
        $p = $q.Dequeue(); $px = $p % $w; $py = [int][math]::Floor($p / $w)
        $neighbors = @()
        if ($px -gt 0) { $neighbors += ($p - 1) }
        if ($px -lt $w - 1) { $neighbors += ($p + 1) }
        if ($py -gt 0) { $neighbors += ($p - $w) }
        if ($py -lt $h - 1) { $neighbors += ($p + $w) }
        foreach ($np in $neighbors) {
            if ($removed[$np]) { continue }
            $nx = $np % $w; $ny = [int][math]::Floor($np / $w); $nidx = $ny * $stride + $nx * 4
            $dr = $buf[$nidx + 2] - $keyR; $dg = $buf[$nidx + 1] - $keyG; $db = $buf[$nidx] - $keyB
            if (($dr * $dr + $dg * $dg + $db * $db) -le $tol2) { $removed[$np] = $true; $buf[$nidx + 3] = 0; $q.Enqueue($np) }
        }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $d.Scan0, $buf.Length)
    $src.UnlockBits($d)
}

# Row index just past the lowest opaque pixel (the character's visible bottom / feet),
# so frames can be aligned by content instead of by their transparent-padded frame edge.
function Content-Bottom($src) {
    $w = $src.Width; $h = $src.Height
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $d = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $d.Stride
    $buf = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $buf, 0, $buf.Length)
    $src.UnlockBits($d)
    for ($y = $h - 1; $y -ge 0; $y--) {
        $row = $y * $stride
        for ($x = 0; $x -lt $w; $x++) {
            if ($buf[$row + $x * 4 + 3] -gt 8) { return $y + 1 }
        }
    }
    return $h
}

# Tight bounding box of opaque pixels: [left, top, right, bottom] (or $null if empty).
function Content-Bounds($src) {
    $w = $src.Width; $h = $src.Height
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $d = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $d.Stride
    $buf = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $buf, 0, $buf.Length)
    $src.UnlockBits($d)
    $left = $w; $top = $h; $right = -1; $bottom = -1
    for ($y = 0; $y -lt $h; $y++) {
        $row = $y * $stride
        for ($x = 0; $x -lt $w; $x++) {
            if ($buf[$row + $x * 4 + 3] -gt 8) {
                if ($x -lt $left) { $left = $x }
                if ($x -gt $right) { $right = $x }
                if ($y -lt $top) { $top = $y }
                if ($y -gt $bottom) { $bottom = $y }
            }
        }
    }
    if ($right -lt 0) { return $null }
    return @($left, $top, $right, $bottom)
}

function Convert-Frame($srcPath, $outPath, $align = "bottom") {
    $raw = [System.Drawing.Bitmap]::FromFile($srcPath)
    $src = To32bpp $raw
    $raw.Dispose()
    if ($keyMode -eq "flood") { Flood-Key $src } else { $src.MakeTransparent($keyColor) }
    $canvas = New-Object System.Drawing.Bitmap $maxW, $maxH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [System.Drawing.Graphics]::FromImage($canvas)
    if ($align -eq "center") {
        # Center the content in the canvas (for effects that spawn at a point).
        $b = Content-Bounds $src
        if ($b -ne $null) {
            $cw = $b[2] - $b[0] + 1; $ch = $b[3] - $b[1] + 1
            $offX = [int](($maxW - $cw) / 2) - $b[0]
            $offY = [int](($maxH - $ch) / 2) - $b[1]
            $g2.DrawImage($src, $offX, $offY)
        }
    } else {
        # Align the character's visible bottom (feet) to the canvas bottom so it isn't floating.
        $offY = $maxH - (Content-Bottom $src)
        $g2.DrawImage($src, [int](($maxW - $src.Width) / 2), $offY)
    }
    $g2.Dispose()
    $canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $src.Dispose(); $canvas.Dispose()
}

$charDir = Join-Path $proj ("Assets/CharAsset/" + $map.name)
$ext = New-Object System.Text.StringBuilder
$anims = New-Object System.Text.StringBuilder
$id = 0

foreach ($name in $map.anims.PSObject.Properties.Name) {
    $a = $map.anims.$name
    $animDir = Join-Path $charDir $name
    New-Item -ItemType Directory -Force -Path $animDir | Out-Null
    Get-ChildItem $animDir -Filter *.png -ErrorAction SilentlyContinue | Remove-Item -Force
    $align = if ($a.PSObject.Properties.Name -contains "align") { $a.align } else { "bottom" }
    $frameEntries = @()
    $local = 0
    foreach ($i in (Expand-Ranges $a)) {
        if (-not $frameByNum.ContainsKey($i)) {
            Write-Output "  (skip missing frame $i in '$name')"
            continue
        }
        $outName = ("{0}_{1:D2}.png" -f $name, $local)
        Convert-Frame $frameByNum[$i].FullName (Join-Path $animDir $outName) $align
        $id++
        $resPath = "res://Assets/CharAsset/$($map.name)/$name/$outName"
        [void]$ext.AppendLine("[ext_resource type=`"Texture2D`" path=`"$resPath`" id=`"$id`"]")
        $frameEntries += "{`n`"duration`": 1.0,`n`"texture`": ExtResource(`"$id`")`n}"
        $local++
    }
    $loopStr = if ($a.loop) { "true" } else { "false" }
    [void]$anims.AppendLine("{")
    [void]$anims.AppendLine("`"frames`": [$($frameEntries -join ', ')],")
    [void]$anims.AppendLine("`"loop`": $loopStr,")
    [void]$anims.AppendLine("`"name`": &`"$name`",")
    [void]$anims.AppendLine("`"speed`": $([int]$a.fps).0")
    [void]$anims.AppendLine("}, ")
    Write-Output ("  {0}: {1} frames" -f $name, (Expand-Ranges $a).Count)
}

$tres = "[gd_resource type=`"SpriteFrames`" load_steps=$($id + 1) format=3 uid=`"uid://frames$($map.name)`"]`n`n"
$tres += $ext.ToString() + "`n[resource]`n"
$tres += "animations = [" + $anims.ToString() + "]`n"
$tresPath = Join-Path $charDir ($map.name + "_frames.tres")
# Write UTF-8 WITHOUT BOM — Godot's .tres parser rejects a leading BOM.
[System.IO.File]::WriteAllText($tresPath, $tres, (New-Object System.Text.UTF8Encoding $false))
Write-Output "Wrote $tresPath"
