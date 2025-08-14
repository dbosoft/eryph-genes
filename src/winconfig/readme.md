# {{ manifest.short_description }}

This geneset contains fodder genes for common configuration tasks of a Windows catlet.

## Usage


### join-domain

Using the fodder join-domain you can join windows catlet to a domain.   
The fodder will automatically reboot the catlet after joining the domain.

**Variables:** 
- domain_name:  
  name of the domain to join
- domain_admin:  
  name of the domain admin user
- domain_admin_password:  
  password of the domain admin user


### enable-ssh

With the fodder enable-ssh, you can enable the SSH server feature in Windows.
This gene requires Windows Server 2019 (or Windows 10 1809) or newer. The
corresponding Windows feature does not exist in older versions of Windows.


### devdrive

The devdrive fodder configures a Dev Drive (Windows 11) or ReFS development volume (older Windows) for optimized development performance.
On Windows 11 Build 22621+, it creates a true Dev Drive with trust settings and antivirus optimizations.
On older Windows versions, it creates a ReFS volume that still provides better performance than NTFS.

**Variables:**
- devdrive_name (required):  
  Eryph drive name (e.g., sdb, sdc) - must match the drive defined in your catlet
- devdrive_letter (optional, default: "E"):  
  Windows drive letter to assign
- devdrive_label (optional, default: "DevDrive"):  
  Volume label for the drive

The fodder automatically:
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
  - source: gene:dbosoft/winconfig:devdrive
    variables:
      - name: devdrive_name
        value: sdb
      - name: devdrive_letter
        value: E
      - name: devdrive_label
        value: DevDrive
```

**Integration with Visual Studio:**

The devdrive gene works seamlessly with the Visual Studio gene. When used together, Visual Studio will automatically detect the Dev Drive and create appropriate project directories:

```yaml
fodder:
  # Configure Dev Drive first
  - source: gene:dbosoft/winconfig:devdrive
    variables:
      - name: devdrive_name
        value: sdb
  
  # Then install Visual Studio
  - source: gene:dbosoft/msvs:vs2022
    # VS will auto-detect and use the Dev Drive
```

**Created directory structure:**

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


---

{{> food_versioning_major_minor }}

{{> footer }}

