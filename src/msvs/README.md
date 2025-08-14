# Microsoft Visual Studio

This geneset contains fodder for installing Microsoft Visual Studio 2022 in Windows catlets.

## Usage

To install Visual Studio 2022 in your Windows catlets, add a gene reference:

``` yaml
fodder:
 - source: gene:dbosoft/msvs:vs2022
```

## Configuration

The vs2022 gene supports the following variables to configure the installation:

### Edition and Location

- **vs_edition**  
  default value: Community
  
  The Visual Studio edition to install. Valid values: `Community`, `Professional`, `Enterprise`.

- **vs_install_path**  
  default value: C:\Program Files\Microsoft Visual Studio\2022\Community
  
  Installation directory. Automatically adjusts based on edition if using default path.

### Installation Source

- **vs_iso_path**  
  default value: *empty*
  
  Optional path to a Visual Studio ISO file for offline installation. The gene will:
  1. Try the provided ISO path
  2. Auto-detect mounted ISOs on drives E: through H:
  3. Fall back to downloading from the internet

### Workloads and Components

- **vs_workloads**  
  default value: Microsoft.VisualStudio.Workload.ManagedDesktop;Microsoft.VisualStudio.Workload.NetWeb
  
  Semicolon-separated list of workload IDs to install. Common workloads:
  - `Microsoft.VisualStudio.Workload.ManagedDesktop` - .NET Desktop Development
  - `Microsoft.VisualStudio.Workload.NetWeb` - ASP.NET and Web Development
  - `Microsoft.VisualStudio.Workload.Azure` - Azure Development
  - `Microsoft.VisualStudio.Workload.NativeDesktop` - Desktop Development with C++
  - `Microsoft.VisualStudio.Workload.Data` - Data Storage and Processing

- **vs_components**  
  default value: *empty*
  
  Semicolon-separated list of individual component IDs for fine-tuned control.

- **include_recommended**  
  default value: true
  
  Include recommended components for selected workloads.

- **include_optional**  
  default value: false
  
  Include optional components for selected workloads.

### Localization

- **vs_languages**  
  default value: en-US
  
  Semicolon-separated list of language codes to install. Common codes:
  - `en-US` - English (United States)
  - `de-DE` - German
  - `fr-FR` - French
  - `ja-JP` - Japanese
  - `zh-CN` - Chinese (Simplified)

### Dev Drive Integration

- **dev_drive_letter**  
  default value: *empty*
  
  Optional drive letter for Dev Drive. When provided, Visual Studio will configure its project directories to use this drive. If not provided, the gene will auto-detect Dev Drive on Windows 11 or ReFS drives labeled as "Dev*".

## Examples

### Basic Installation

Install Community edition with default .NET workloads:

``` yaml
fodder:
 - source: gene:dbosoft/msvs:vs2022
```

### Professional Edition with Azure Development

``` yaml
fodder:
 - source: gene:dbosoft/msvs:vs2022
   variables:
     - name: vs_edition
       value: Professional
     - name: vs_workloads
       value: "Microsoft.VisualStudio.Workload.Azure;Microsoft.VisualStudio.Workload.Data"
```

### Enterprise Edition with Multiple Languages

``` yaml
fodder:
 - source: gene:dbosoft/msvs:vs2022
   variables:
     - name: vs_edition
       value: Enterprise
     - name: vs_languages
       value: "en-US;de-DE;fr-FR"
     - name: vs_workloads
       value: "Microsoft.VisualStudio.Workload.ManagedDesktop;Microsoft.VisualStudio.Workload.NativeDesktop"
```

### Offline Installation with ISO

Add the Visual Studio ISO as a disk to your catlet with recommended resource allocation:

``` yaml
cpu: 8
memory: 16384

drives:
 - name: sda
   size: 100
 - name: sdb
   source: \\server\share\vs_enterprise_2022.iso
   type: dvd

fodder:
 - source: gene:dbosoft/msvs:vs2022
```

The gene will automatically detect the mounted ISO on drives E: through H: and use it for offline installation.

### Dev Drive Integration

Create a high-performance development environment with Dev Drive and Visual Studio:

``` yaml
name: vs-dev-environment
parent: dbosoft/win11-24h2-enterprise/starter

cpu: 8
memory: 16384

drives:
 - name: sda
   size: 60
 - name: sdb
   size: 100  # Dev Drive

fodder:
 # Configure Dev Drive first
 - source: gene:dbosoft/winconfig:devdrive
   variables:
     - name: devdrive_name
       value: sdb
     - name: devdrive_letter
       value: E
     - name: devdrive_label
       value: DevDrive
 
 # Install Visual Studio with Dev Drive auto-detection
 - source: gene:dbosoft/msvs:vs2022
   variables:
     - name: vs_edition
       value: Community
     # VS will auto-detect the Dev Drive at E:
```

When Visual Studio detects a Dev Drive, it automatically creates the following directory structure:

```
E:\
├── source\
│   ├── repos\         # VS project location
│   ├── projects\      # Additional projects
│   └── templates\     # User templates
│       ├── ProjectTemplates\
│       └── ItemTemplates\
├── SymbolCache\       # Debug symbols
├── .nuget\            # NuGet packages
├── npm-cache\         # NPM cache
├── pip-cache\         # Python packages
└── [other caches...]  # Various development caches
```

#### Configuring Visual Studio for Dev Drive

When a Dev Drive is detected during Visual Studio installation, the gene automatically creates the appropriate directory structure on the Dev Drive. However, Visual Studio project settings are per-user and must be configured manually.

**Manual Configuration in Visual Studio**:
   - Open Visual Studio
   - Go to **Tools → Options → Projects and Solutions → Locations**
     - Projects location: `E:\source\repos`
     - User project templates: `E:\source\templates\ProjectTemplates`
     - User item templates: `E:\source\templates\ItemTemplates`
   - Go to **Tools → Options → Debugging → Symbols**
     - Symbol cache directory: `E:\SymbolCache`

#### Performance Benefits

Dev Drive provides approximately 25% better performance for:
- Build operations
- File I/O operations
- Package restore
- Git operations
- IntelliSense indexing

#### Explicit Dev Drive Configuration

If you need to specify a particular drive letter (e.g., for Windows Server 2022 with ReFS):

``` yaml
fodder:
 - source: gene:dbosoft/msvs:vs2022
   variables:
     - name: dev_drive_letter
       value: D  # Explicitly use D: drive
```

## Requirements

- **Base Image**: Windows 10/11 or Windows Server 2019/2022
- **CPU**: Minimum 4 cores, 8 recommended
- **Memory**: Minimum 4 GB, 16 GB recommended
- **Disk**: 20-50 GB depending on workloads

### Recommended Catlet Configuration

``` yaml
cpu: 8
memory: 16384

drives:
 - name: sda
   size: 100
```

## Licensing

- **Community**: Free for individuals, open source, academic research, and small teams (up to 5 users)
- **Professional/Enterprise**: Requires valid license or subscription

After installation, you'll need to activate the license by signing in with your Microsoft account or entering a product key.

## References

- [Visual Studio Silent Installation](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio)
- [Workload and Component IDs](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-community)
- [Visual Studio System Requirements](https://learn.microsoft.com/en-us/visualstudio/releases/2022/system-requirements)

---

{{> food_versioning_major_minor }}

{{> footer }}