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

With the fodder enable-ssh, you can enable SSH server feature in Windows.
This gene requires Windows Server 2019 (or Windows 10 1809) or newer. The
corresponding Windows feature does not exist in older versions of Windows.


{{> food_versioning_major_minor }}

{{> footer }}

