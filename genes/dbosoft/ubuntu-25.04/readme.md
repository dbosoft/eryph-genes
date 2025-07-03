
# Ubuntu 25.04

This geneset contains the base catlet for Ubuntu 25.04.

## Usage

The base catlet can be used as parent catlet like this

``` ps
New-Catlet -Parent "dbosoft/ubuntu-25.04"
```

This base catlet does not include a default user.  
You should therefore set up your own fodder to create an initial local user or to automatically join a domain.  

Alternatively, you can use the Starter Catlet, which creates a default admin user with an initial password of "admin".


``` ps
New-Catlet -Parent "dbosoft/ubuntu-25.04/starter"
```


See also [starter-food](/b/dbosoft/starter-food) for other defaults and variables for starter food. 



----    
  
# General Information

## Ubuntu Catlets Naming Convention

The naming convention for the server catlets is as follows:

`ubuntu-<version>`

where `<version>` is the Ubuntu version, e.g. `22.04`.  
We only build long-term support (LTS) versions of Ubuntu.    

## Monthly Builds

We **plan** to build the server catlets monthly. The build date is part of the tag name.
The tag `latest` is updated with each released version.  

Currently the builds have to be triggered manually. We are working on automating this process. 



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

