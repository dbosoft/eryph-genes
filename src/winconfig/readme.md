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

{{> food_versioning_major_minor }}

{{> footer }}

