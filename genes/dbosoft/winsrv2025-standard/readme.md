
# Windows Server 2025 Standard

This geneset contains the base catlet for Windows Server 2025 Standard.

## Usage

The base catlet can be used as parent catlet like this

``` ps
New-Catlet -Parent "dbosoft/winsrv2025-standard"
```

However, this base catlet does not include a default user. 
You should therefore set up your own fodder to create an initial local user or to join a domain. 

Alternatively, you can use the starter catlet, which creates a default user admin with an initial password of "InitialPassw0rd".

``` ps
New-Catlet -Parent "dbosoft/winsrv2025-standard/starter"
```

See also https://genepool.eryph.io/b/dbosoft/starter-food for other defaults and options for starter food. 


## Windows license

All base catlets from dbosoft contain no valid windows license and are build using a evaluation image.
This means that the license will expire after some time since the initial build and will need to be rearmed (see https://sid-500.com/2017/08/08/windows-server-2016-evaluation-how-to-extend-the-trial-period/).

However you should not use the windows base catlets in production. 

Instead, it is recommended that you create your own base catlet with Windows activation enabled. You can use the https://github.com/eryph-org/basecatlets-hyperv project as a starting point for your own base catlets and customizations. See the cloudbase init documentation for supported methods to activate windows: https://cloudbase-init.readthedocs.io/en/latest/plugins.html#licensing-main