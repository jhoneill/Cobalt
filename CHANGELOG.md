# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Pre-relase] - 2022-07-13
### Added
- Local caching of Winget repository information **This requires the GetSQL module**
- Get-InstalledSoftware which can match installed software to packages in the repo
### Changed
- `Find-WinGetPackage` to use the cached repo and rest calls to the MS store. (Won't currently support Private repos)
- `Get-WinGetPackageInfo` to download and process the manifest **which needs the PowerShell-Yaml module**
- The new commands are in file which is merged into the PSM1 file. The original build didn't work with the current download of crescendo, but does work with my version https://github.com/jhoneill/Crescendo/tree/James which can set more options in the PSD1 file, so build.ps1 has been updated accordingly. 

## [0.3.1] - 2022-05-13
### Fixed
- Package upgrade list functionality now correctly supports non-EN-US localities

## [0.3.0] - 2022-05-12
### Added
- Ability to return a list of packages that qualify for updates
### Changed
- `Get-WinGetPackage` now returns both installed and available version information

## [0.2.1] - 2022-03-12
### Fixed
- Package uninstallation error handling should now correctly catch failures

## [0.2.0] - 2022-03-12
### Added
- Ability to retrieve package metadata and versions
- Uninstall failure error handling
### Fixed
- Package installation error handling should now correctly catch failures with non-US English languages

## [0.1.0] - 2022-02-06
### Added
- Upgrade functionality

## [0.0.11] - 2022-01-22
### Changed
- Error output is more targeted to only what failed

## [0.0.10] - 2021-12-26
### Fixed
- Correctly source display language information
- Force console encoding in automated tests

## [0.0.9] - 2021-12-21
### Fixed
- Handle non-US English locales correctly

## [0.0.8] - 2021-12-21
### Fixed
- More dynamic locale-based column parsing

## [0.0.7] - 2021-12-04
### Fixed
- Even more string parsing corrections

## [0.0.6] - 2021-12-04
### Fixed
- Yet more string parsing corrections

## [0.0.5] - 2021-12-04
### Fixed
- Additional string parsing/cleaning corrections

## [0.0.4] - 2021-12-04
### Fixed
- Improved and consolidated string parsing/cleaning

## [0.0.3] - 2021-12-04
### Fixed
- Correctly order output package attributes

## [0.0.2] - 2021-12-04
### Fixed
- Correctly handle output when no results are found with `list` or `search` commands

## [0.0.1] - 2021-12-02
- Initial release
