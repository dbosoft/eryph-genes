# Windows Computer Configuration

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



### rearm-eval

Automatically extends the Windows evaluation license period when it's about to expire.

Windows evaluation editions (e.g., Windows Server 2022 Evaluation) come with a 180-day trial that can be extended up to 6 times using the rearm command, providing up to 3 years of use. This fodder:
- Checks license status on each boot
- Automatically rearms when the evaluation period expires or has less than 10 days remaining
- Handles network connectivity checks for activation
- Triggers automatic reboot after successful rearm

No variables required. Simply add to your evaluation edition catlet:

```yaml
fodder:
  - source: gene:dbosoft/winconfig:rearm-eval
```


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


