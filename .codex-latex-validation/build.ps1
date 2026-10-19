[CmdletBinding()]
param(
    [ValidateSet('SRS', 'HazardAnalysis', 'All')]
    [string]$Document = 'All',
    [ValidateRange(1, 5)]
    [int]$Passes = 3,
    [switch]$PrepareOnly
)

$ErrorActionPreference = 'Stop'
$validationRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repositoryRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $validationRoot))
$expectedRepository = 'C:\Users\sanka\Documents\Github\FPVR'
if (-not $repositoryRoot.Equals($expectedRepository, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Validation script is outside the authorized repository: $repositoryRoot"
}

function Assert-RepositoryPath([string]$Candidate) {
    $absolutePath = [System.IO.Path]::GetFullPath($Candidate)
    $repositoryPrefix = $repositoryRoot.TrimEnd('\') + '\'
    if (-not $absolutePath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Write target is outside the authorized repository: $absolutePath"
    }
    return $absolutePath
}

$installedMiKTeX = 'C:\Users\sanka\AppData\Local\Programs\MiKTeX'
$originalData = 'C:\Users\sanka\AppData\Local\MiKTeX'
$originalConfig = 'C:\Users\sanka\AppData\Roaming\MiKTeX'
$pdfLaTeX = Join-Path $installedMiKTeX 'miktex\bin\x64\pdflatex.exe'
if (-not (Test-Path -LiteralPath $pdfLaTeX -PathType Leaf)) {
    throw "The existing pdflatex executable was not found: $pdfLaTeX"
}

$configurationDirectory = Assert-RepositoryPath (Join-Path $validationRoot 'config\miktex\config')
$formatDirectory = Assert-RepositoryPath (Join-Path $validationRoot 'data\miktex\data\le\pdftex')
$fontMapDirectory = Assert-RepositoryPath (Join-Path $validationRoot 'data\fonts\map\pdftex')
$directories = @(
    $configurationDirectory,
    $formatDirectory,
    $fontMapDirectory,
    (Join-Path $validationRoot 'install'),
    (Join-Path $validationRoot 'logs'),
    (Join-Path $validationRoot 'temp'),
    (Join-Path $validationRoot 'output\SRS'),
    (Join-Path $validationRoot 'output\HazardAnalysis')
)
foreach ($directory in $directories) {
    $directory = Assert-RepositoryPath $directory
    [void](New-Item -ItemType Directory -Path $directory -Force)
}

# All source paths below are read-only inputs. Copies and generated data stay here.
$configurationFiles = @(
    'pdflatex.ini', 'pdftex.ini', 'texmfapp.ini', 'texapp.ini',
    'formats.ini', 'languages.ini'
)
foreach ($configurationFile in $configurationFiles) {
    $source = Join-Path $installedMiKTeX "miktex\config\$configurationFile"
    $destination = Assert-RepositoryPath (Join-Path $configurationDirectory $configurationFile)
    Copy-Item -LiteralPath $source -Destination $destination -Force
}
$localFormat = Assert-RepositoryPath (Join-Path $formatDirectory 'pdflatex.fmt')
Copy-Item -LiteralPath (Join-Path $originalData 'miktex\data\le\pdftex\pdflatex.fmt') -Destination $localFormat -Force
Copy-Item -LiteralPath (Join-Path $originalData 'fonts\map\pdftex\pdftex.map') -Destination (Assert-RepositoryPath (Join-Path $fontMapDirectory 'pdftex.map')) -Force

# File-based configuration prevents MiKTeX from persisting settings to the registry.
@'
[Core]
NoRegistry = true
AutoAdmin = false
AllowUnsafeOutputFiles = false
ShellCommandMode = Forbidden
[MPM]
AutoInstall = false
'@ | Set-Content -LiteralPath (Assert-RepositoryPath (Join-Path $configurationDirectory 'miktex.ini')) -Encoding ASCII

if ($PrepareOnly) {
    Write-Output "Prepared repository-local MiKTeX validation environment: $validationRoot"
    return
}

$environmentValues = @{
    MIKTEX_USERCONFIG = (Join-Path $validationRoot 'config')
    MIKTEX_USERDATA = (Join-Path $validationRoot 'data')
    MIKTEX_USERINSTALL = (Join-Path $validationRoot 'install')
    # MiKTeX explicitly treats Other roots as read-only.
    MIKTEX_OTHERUSERROOTS = "$installedMiKTeX;$originalData;$originalConfig"
    MIKTEX_CORE_USERLOGDIRECTORY = (Join-Path $validationRoot 'logs')
    MIKTEX_CORE_COMMONLOGDIRECTORY = (Join-Path $validationRoot 'logs')
    MIKTEX_CORE_TEMPDIR = (Join-Path $validationRoot 'temp')
    MIKTEX_CORE_NOREGISTRY = 'true'
    MIKTEX_CORE_AUTOADMIN = 'false'
    MIKTEX_CORE_ALLOWUNSAFEOUTPUTFILES = 'false'
    MIKTEX_CORE_SHELLCOMMANDMODE = 'Forbidden'
    MIKTEX_MPM_AUTOINSTALL = 'false'
    MIKTEX_PKGLISTFILE = (Join-Path $validationRoot 'package-usage.txt')
    MIKTEX_EXCEPTION_PATH = (Join-Path $validationRoot 'exception.log')
    TEMP = (Join-Path $validationRoot 'temp')
    TMP = (Join-Path $validationRoot 'temp')
    TMPDIR = (Join-Path $validationRoot 'temp')
    TEMPDIR = (Join-Path $validationRoot 'temp')
    TEXMFOUTPUT = (Join-Path $validationRoot 'output')
}
$previousEnvironment = @{}
foreach ($name in $environmentValues.Keys) {
    $previousEnvironment[$name] = [System.Environment]::GetEnvironmentVariable($name, 'Process')
    [System.Environment]::SetEnvironmentVariable($name, $environmentValues[$name], 'Process')
}

try {
    $documents = @{
        SRS = 'docs\SRS\SRS.tex'
        HazardAnalysis = 'docs\HazardAnalysis\HazardAnalysis.tex'
    }
    $selectedDocuments = if ($Document -eq 'All') { @('SRS', 'HazardAnalysis') } else { @($Document) }
    foreach ($selectedDocument in $selectedDocuments) {
        $sourcePath = Join-Path $repositoryRoot $documents[$selectedDocument]
        $outputDirectory = Assert-RepositoryPath (Join-Path $validationRoot "output\$selectedDocument")
        Push-Location -LiteralPath (Split-Path -Parent $sourcePath)
        try {
            for ($pass = 1; $pass -le $Passes; $pass++) {
                Write-Output "Compiling $selectedDocument, pass $pass of $Passes"
                & $pdfLaTeX `
                    --disable-installer `
                    --disable-write18 `
                    --dont-parse-first-line `
                    --interaction=nonstopmode `
                    --halt-on-error `
                    --recorder `
                    "--undump=$localFormat" `
                    "--output-directory=$outputDirectory" `
                    "--aux-directory=$outputDirectory" `
                    (Split-Path -Leaf $sourcePath)
                if ($LASTEXITCODE -ne 0) {
                    throw "pdflatex failed for $selectedDocument on pass $pass (exit $LASTEXITCODE)."
                }
            }
        }
        finally {
            Pop-Location
        }
    }
}
finally {
    foreach ($name in $environmentValues.Keys) {
        [System.Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
    }
}
