# Starter Food

This geneset contains starter food that could be consumed by catlets for quick starts.

## Usage

Dbosoft base catlets that supports starter food contain a tag "starter" that uses the latest base catlet version and latest starter food version. 

To use it in your own windows catlets add a gene reference to the windows starter gene:

``` yaml
fodder:
 - source: gene:dbosoft/starter-food:win-starter
```

or for linux:


``` yaml
fodder:
 - source: gene:dbosoft/starter-food:linux-starter
```

-----

# Linux starter food

Linux starter food is in the fooder gene `linux-starter`  and contains currently one one gene to set up a default user.


## Default user

The starter food linux-starter contains a default user configuration with username admin and password admin. 
Following variables can be used to configure the defaults:

- **username**  
  default value: admin
  
  Name of the created user

- **password**  
  default value: admin

  Password of the created user

- **lockPassword**  
  default value: false    

  Boolean value to disable password login - to be used to disable password with public key login enabled only - see sshPublicKey

- **sshPublicKey**  
  
  Optional value for a ssh public key (as a string), that will be configured for created user as ssh key.


-----

# Windows starter food

Windows starter food is in the fooder gene `windows-starter`. 
If the entire gene is referenced all fodder configurations will be fed into the catlet. The starter settings enables a default user, remote desktop and SSH access. 

## Default user

The starter food linux-starter contains a default user configuration with username admin and password admin. 
Following variables can be used to configure the defaults:

- **AdminUsername**  
  default value: admin
  
  Name of the created user

- **AdminPassword**  
  default value: InitialPassw0rd

  Password of the created user


## Remote Desktop Access

The gene `remote-desktop` enables the remote desktop access to the catlet. There are no configuration options. 



## SSH Server

The gene `ssh-server` enables the buildin SSH Server that is included in modern Windows Versions. Windows Server 2016 is not supported. 


---

{{> food_versioning_major_minor }}

{{> footer }}

