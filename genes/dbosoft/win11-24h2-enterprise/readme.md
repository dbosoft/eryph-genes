
# Windows 11 24H2 Enterprise

This geneset contains the base catlet for Windows 11 24H2 Enterprise.

## Usage

The base catlet can be used as parent catlet like this

``` ps
New-Catlet -Parent "dbosoft/win11-24h2-enterprise"
```

This base catlet does not include a default user.  
You should therefore set up your own fodder to create an initial local user or to automatically join a domain.  

Alternatively, you can use the Starter Catlet, which creates a default admin user with an initial password of "InitialPassw0rd".


``` ps
New-Catlet -Parent "dbosoft/win11-24h2-enterprise/starter"
```


See also [starter-food](/b/dbosoft/starter-food) for other defaults and variables for starter food. 
  
&nbsp; 

## Windows license

All base catlets from dbosoft contain no valid windows license and are build using a evaluation image.  
This means that the license will expire after some time since the initial build and will need to be rearmed (see also [here](https://sid-500.com/2017/08/08/windows-server-2016-evaluation-how-to-extend-the-trial-period/)).

If the catlet can access the Internet at startup, the automatic activation will be activated for 90-180 days (depending on the Windows version).  
  
&nbsp;  
Legal note: By activating the Windows license, you also accept the Windows evaluation license.   
&nbsp;  
  
**You should not use the windows base catlets in production.**
&nbsp;  

Instead, it is recommended that you create your own base catlet that contains or activates your own license.  
&nbsp;  
You can use the [eryph-org/basecatlets-hyperv](https://github.com/eryph-org/basecatlets-hyperv) project as a starting point for your own base catlets and customizations. 



----

# Versioning

This geneset contains 2 kinds of tags:

- Base catlets  
  Base catlets are versioned by a timestamp which is the build date of the catlet.  
  The tag latest is updated with each released version. 

- Starter catlets  
  Starter catlets are versioned with a major-minor version scheme.

  The started catlets are very light and contain only reference to the base catlet and the starter food.



----

# Contributing

This geneset is maintained by dbosoft and is open for contributions.  

You can find the repository for this geneset on [github.com/dbosoft/eryph-genes](https://github.com/dbosoft/eryph-genes).  

  

# License

All public dbosoft genesets are licensed under the [MIT License](https://opensource.org/licenses/MIT).

