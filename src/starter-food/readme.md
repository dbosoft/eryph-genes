# Starter Food

This geneset contains starter food that could be consumed by catlets for quick starts.

## Usage

dbosoft base catlets that supports starter food contain a tag "starter" that uses the latest base catlet version and latest starter food version. 

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

# Linux variables and defaults

## Default user

The starter food linux-starter contains a default user configuration with username admin and password admin. 
Following variables can be used to configure the defaults:

- username  
  default value: admin
  
  Name of the created user

- name: password  
  default value: admin

  Password of the created user

- lockPassword  
  default value: false    

  Boolean value to disable password login - to be used to disable password with public key login enabled only - see sshPublicKey

- sshPublicKey  
  
  Optional value for a ssh public key (as a string), that will be configured for created user as ssh key.


