# Windows Dev Drive configuration for optimized development performance

The windevdrive geneset configures a Dev Drive (Windows 11) or ReFS development volume (older Windows) for optimized development performance. Dev Drives provide significant performance improvements for development workloads through reduced antivirus scanning and optimized file system operations.

## Features

On Windows 11 Build 22621+, it creates a true Dev Drive with:
- Trust settings for improved performance
- Antivirus optimizations and exclusions
- ReFS file system with performance tuning

On older Windows versions, it creates a ReFS volume that still provides better performance than NTFS for development workloads.

## Usage

### configure

The configure fodder sets up the development drive with optimal settings and directory structure.

**Variables:**
- devdrive_name (required):  
  Eryph drive name (e.g., sdb, sdc) - must match the drive defined in your catlet
- devdrive_letter (optional, default: "E"):  
  Windows drive letter to assign
- devdrive_label (optional, default: "DevDrive"):  
  Volume label for the drive

The fodder automatically:
- Initializes and partitions the specified drive
- Formats as Dev Drive (Windows 11) or ReFS (older versions)
- Creates package cache directories for NuGet, npm, pip, Maven, Gradle, Cargo, and vcpkg
- Sets system-wide environment variables for package managers
- Creates a standard developer workspace structure
- Configures Dev Drive trust and antivirus settings (Windows 11 only)

**Example usage:**

```yaml
name: dev-workstation
parent: dbosoft/win11-24h2-enterprise/starter

drives:
- name: sda
  size: 60
- name: sdb
  size: 100  # Additional drive for Dev Drive

fodder:
  - source: gene:dbosoft/windevdrive:configure
    variables:
      - name: devdrive_name
        value: sdb
      - name: devdrive_letter
        value: E
      - name: devdrive_label
        value: DevDrive
```

## Integration with Visual Studio

The windevdrive gene works seamlessly with the Visual Studio gene. When used together, Visual Studio will automatically detect the Dev Drive and create appropriate project directories:

```yaml
fodder:
  # Configure Dev Drive first
  - source: gene:dbosoft/windevdrive:configure
    variables:
      - name: devdrive_name
        value: sdb
  
  # Then install Visual Studio
  - source: gene:dbosoft/msvs:vs2022
    # VS will auto-detect and use the Dev Drive
```

## Created Directory Structure

The following directory structure is created on the configured drive:

```
E:\
├── source\
│   ├── repos\         # Git repositories
│   └── projects\      # Other projects
├── tools\             # Development tools
├── temp\              # Build temp files
├── .nuget\            # NuGet cache (NUGET_PACKAGES)
├── npm-cache\         # NPM cache (npm_config_cache)
├── pip-cache\         # Python cache (PIP_CACHE_DIR)
├── maven-cache\       # Maven cache (MAVEN_OPTS)
├── gradle-cache\      # Gradle cache (GRADLE_USER_HOME)
├── cargo-cache\       # Rust cache (CARGO_HOME)
└── vcpkg-cache\       # vcpkg cache (VCPKG_DEFAULT_BINARY_CACHE)
```

## Environment Variables

The following environment variables are set system-wide:

- `NUGET_PACKAGES`: Points to .nuget cache directory
- `npm_config_cache`: Points to npm cache directory
- `PIP_CACHE_DIR`: Points to pip cache directory
- `MAVEN_OPTS`: Includes local repository path
- `GRADLE_USER_HOME`: Points to gradle cache directory
- `CARGO_HOME`: Points to cargo cache directory
- `VCPKG_DEFAULT_BINARY_CACHE`: Points to vcpkg cache directory

## Performance Benefits

Dev Drives provide:
- Up to 30% faster build times
- Reduced file system overhead
- Optimized for developer workloads
- Automatic antivirus exclusions
- Copy-on-write capabilities with ReFS

## Requirements

- Windows 11 Build 22621+ for full Dev Drive support
- Windows 10 1709+ or Windows Server 2016+ for ReFS support
- An additional drive configured in your catlet

---


# Versioning

This geneset contains only fodder genes and is versioned with a major-minor version scheme.  

There is no patch version - when a bug is fixed, a new minor version will be released.  
A new major version is released when a gene is removed from the geneset. 

The tag latest is updated with each released version. If you want to have a stable reference, don't use the latest tag, use a specific version tag. 

----

# Contributing

This geneset is maintained by dbosoft and is open for contributions.  

You can find the repository for this geneset on [github.com/dbosoft/eryph-genes](https://github.com/dbosoft/eryph-genes).  

  

# License

All public dbosoft genesets are licensed under the [MIT License](https://opensource.org/licenses/MIT).

