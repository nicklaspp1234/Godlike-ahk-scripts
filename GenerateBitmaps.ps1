# Create needle bitmaps from a screenshot.
#
# This should really be written in AHK with the Gdip library, but that
# library has problems accessing the GDI+ encoders. This uses .NET and
# produces reliable results :)

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[String]$ScreenshotPath,
	[Parameter(Mandatory=$true)]
	[ValidateSet("Windowed", "Fullscreen")]
	[String]$WindowType
)

# Enforce best practices.
Set-StrictMode -Version Latest
# Stop on first error.
$ErrorActionPreference = 'Stop'

function EnsureDir($Dir) {
	if (Test-Path -LiteralPath $Dir -PathType Container) {
		return
	}
	mkdir $Dir | Out-Null
	Write-Verbose "Created $dir"
}

function FormatSize($Size) {
	"$($Size.Width)x$($Size.Height)"
}

Add-Type -AssemblyName System.Drawing
# .NET doesn't pick up the PowerShell working directory, so pass it an
# absolute path.
$ScreenshotAbspath = (Resolve-Path $ScreenshotPath).Path
try {
	$ScreenshotBitmap = New-Object System.Drawing.Bitmap($ScreenshotAbspath)
}
catch
{
	throw "Could not create bitmap from '$ScreenshotAbspath'. Ensure the image exists."
}

$RequiredSize = New-Object System.Drawing.Size(800, 600)
if ( $ScreenshotBitmap.Size -ne $RequiredSize) {
	throw "Image has dimensions $(FormatSize($ScreenshotBitmap.Size)); expected $(FormatSize($RequiredSize))"
}

$SizeCoords = @{
	'Minor' = @(431, 327, 5, 15);
	'Light' = @(459, 328, 7, 14);
	'Regular' = @(488, 326, 7, 16);
	'Greater' = @(517, 326, 8, 16);
	'Super' = @(547, 323, 6, 19);
}
$Coords = @{}
$TypeIndex = 0
foreach ($Type in @('Healing', 'Mana')) {
	$Coords[$Type] = @{}
	foreach ($SizeItem in $SizeCoords.GetEnumerator()) {
		$Size = $SizeItem.Name
		$Arr = $SizeItem.Value.Clone()
		# Pixel offset of the second inventory row
		$Arr[1] += $TypeIndex * 29
		$Coords[$Type][$Size] = $Arr
	}
	++$TypeIndex
}
$Coords['Rejuvenation'] = @{
	'Regular' = @(430, 386, 8, 13);
	'Full' = @(454, 382, 12, 18);
}
# Again, we need an absolute path for passing to .NET.
$ImagesDir = [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Get-Location) Images) $WindowType))
EnsureDir($ImagesDir)
foreach ($TypeItem in $Coords.GetEnumerator()) {
	$Type = $TypeItem.Name
	$TypeDir = Join-Path $ImagesDir $Type
	EnsureDir($TypeDir)
	foreach ($SizeItem in $TypeItem.Value.GetEnumerator()) {
		$Size = $SizeItem.Name
		$Rect = New-Object System.Drawing.Rectangle($SizeItem.Value)
		$Needle = $ScreenshotBitmap.Clone($Rect, [System.Drawing.Imaging.PixelFormat]::DontCare)
		$NeedlePath = Join-Path $TypeDir "$Size.png"
		$Needle.Save($NeedlePath)
		$Needle.Dispose()
		Write-Verbose "Wrote $NeedlePath"
	}
}
$ScreenshotBitmap.Dispose()
