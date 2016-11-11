function Invoke-Build
{
	Write-Host " "
	Write-Host "Running build script..."

	$build = (msbuild "src\Stripe.sln" /verbosity:minimal /logger:"C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll" | Out-String) -split "\n"

	$missing_comments = 0
	$missing_comments_portable = 0
	$deprecated_types = 0
	$deprecated_types_portable = 0
	$tests_deprecated_types = 0

	foreach($line in $build) {
		if     (${line} -Match "warning CS1591" -and ${line} -Match "Stripe.csproj") { $missing_comments++ }
		elseif (${line} -Match "warning CS0618" -and ${line} -Match "Stripe.csproj") { $deprecated_types++ }
		elseif (${line} -Match "warning CS1591" -and ${line} -Match "Stripe.Portable.csproj") { $missing_comments_portable++ }
		elseif (${line} -Match "warning CS0618" -and ${line} -Match "Stripe.Portable.csproj") { $deprecated_types_portable++ }
		elseif (${line} -Match "warning CS0618" -and ${line} -Match "Stripe.Tests.csproj") { $tests_deprecated_types++ }
		elseif (${line} -Match "warning CS0169" -and ${line} -Match "Stripe.Tests.csproj" -and ${line} -Match ".behaviors" ) { } # do nothing - this is just behaviors
		elseif (${line}) { write-host ${line} }
	}

	Write-Host " "
	Write-Host $("NET45:      $missing_comments publicly visible items are missing XML comments") -ForegroundColor Cyan
	Write-Host $("PORTABLE:   $missing_comments_portable publicly visible items are missing XML comments") -ForegroundColor Cyan
	Write-Host $("NET45:      $deprecated_types items are deprecated") -ForegroundColor Cyan
	Write-Host $("PORTABLE:   $deprecated_types_portable items are deprecated") -ForegroundColor Cyan
	Write-Host $("TESTS:      $tests_deprecated_types tests are targetting deprecated types") -ForegroundColor Cyan

	Write-Host "Finished build script"
	Write-Host " "
}

function Invoke-CopyOutput
{
	Write-Host " "
	Write-Host "Copying assemblies..."

	Copy-Item $env:APPVEYOR_BUILD_FOLDER\src\Stripe\bin\Release\Stripe.net.dll .\build\net45\Stripe.net.dll
	Copy-Item $env:APPVEYOR_BUILD_FOLDER\src\Stripe\bin\Release\Stripe.net.xml .\build\net45\Stripe.net.xml
	Copy-Item $env:APPVEYOR_BUILD_FOLDER\src\Stripe.Portable\bin\Release\Stripe.net.dll .\build\portable\Stripe.net.dll
	Copy-Item $env:APPVEYOR_BUILD_FOLDER\src\Stripe.Portable\bin\Release\Stripe.net.xml .\build\portable\Stripe.net.xml

	Write-Host "Finished copying assemblies"
	Write-Host " "
}

function Invoke-NuGetCheck
{
	Write-Host " "
	Write-Host "Starting NuGet check..."

	$headers = @{
	  "Authorization" = "Bearer $env:token"
	  "Content-type" = "application/json"
	}
 
	$url = "https://ci.appveyor.com/api/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/history?recordsNumber=2"
 
	$history = Invoke-RestMethod -Uri $url -Headers $headers  -Method Get
 
	if ($history.builds.Length -lt 2) {throw "history is not long enough"}
 
	write-host "previous version:"
	$history.builds[1].version
	write-host "current version:"
	$env:APPVEYOR_BUILD_VERSION
 
	$previousVersionSplit = $history.builds[1].version.Split(".")
	if ($previousVersionSplit.Length -lt 3) {throw "previous build version has no enough parts"}
 
	$currentVersionSplit = $env:APPVEYOR_BUILD_VERSION.Split(".")
	if ($currentVersionSplit.Length -lt 3) {throw "current build version has no enough parts"}
 
	$pushNuget = $false
	for ($i = 0; $i -lt 3; $i++) {if ($previousVersionSplit[$i] -ne $currentVersionSplit[$i]) {write-host "at least one part changed, will push nuget"; $pushNuget = $true; break}}
 
	nuget pack  $env:APPVEYOR_BUILD_FOLDER\build\Stripe.net.nuspec

	if(!$pushNuget) {
	write-host "all parts are the same, will not push Nuget"
	# do "nuget pack" here
	# do "appveyor PushArtifact <your-nugetpackage.nupkg>" accordig to https://www.appveyor.com/docs/nuget/
	}

	Write-Host "Finished NuGet check"
	Write-Host " "
}
