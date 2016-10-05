name: dapi-client-bash
version: 1.12.0
release: 0
license: Proprietary
group: Zynga
summary: A simple DAPI command-line client
requires: /bin/bash
requires: curl
buildroot: %{buildroot}

%description
A simple DAPI command-line client to be used for making single-method requests.
View original source at https://github-ca.corp.zynga.com/jowilson/devtools/tree/master/dapi

%files
%defattr(755-,root,root)
/usr/local/bin/dapi

%changelog
* Fri Feb 01 2013 - Josh C. Wilson <jowilson@zynga.com> 1.12.0
    - Adding support for the -O option which makes use of the one-node hosts
* Tue Jan 29 2013 - Josh C. Wilson <jowilson@zynga.com> 1.11.0
    - Better wildcarding on -E and -C options
    - Fixed potential bug with -P option
* Thu Jan 24 2013 - Josh C. Wilson <jowilson@zynga.com> 1.10.0
    - Looks for /etc/dapi-client-bash/.dapirc before ~/.dapirc now
* Thu Jan 24 2013 - Josh C. Wilson <jowilson@zynga.com> 1.9.0
    - Correct return code when using -d
    - Better handling of arguments with internal commas
* Sun Jan 21 2013 - Josh C. Wilson <jowilson@zynga.com> 1.8.0
    - Remove references to ec2
* Tue Jan 15 2013 - Josh C. Wilson <jowilson@zynga.com> 1.7.0
    - Default to https only in prod. The rest use http.
    - Adding -o option to supply curl opts
    - Adding failure codes when the dapi curl call fails
* Mon Jan 14 2013 - Josh C. Wilson <jowilson@zynga.com> 1.6.0
    - Omitting plugin partitioning prefix if -H is specified
* Sun Jan 13 2013 - Josh C. Wilson <jowilson@zynga.com> 1.5.0
    - Adding -x and -X options for XDebug support
    - Adding docs explaining how each command-line arg can be specified in the .dapirc
* Sat Jan 12 2013 - Josh C. Wilson <jowilson@zynga.com> 1.4.0
    - Adding per-environment configs for app id, app secret, zid, and ztoken
* Thu Jan 10 2013 - Josh C. Wilson <jowilson@zynga.com> 1.3.0
    - Adding plugin domain prefix when colo is not specified
* Wed Jan 09 2013 - Josh C. Wilson <jowilson@zynga.com> 1.2.0
    - Adding support for the "---" key prefix to treat values as strings
* Tue Jan 08 2013 - Josh C. Wilson <jowilson@zynga.com> 1.1.0
    - Adding port option and shorthand for auth context option (-c)
* Fri Jan 04 2013 - Josh C. Wilson <jowilson@zynga.com> 1.0.0
    - Initial rpm
