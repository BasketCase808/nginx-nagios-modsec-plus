# Nginx + PHP
## Nagios + ModSec + Nwaf + Brotli + GeoIP2 + SecurityHeaders + HeadersMore + SysGuard + PageSpeed + CookieFlags + TestCookie + CookieLimit + VTS
### +libreSSL

Forked: Need to update with own bits
## Content

__Extra Modules:
- ngx_http_brotli_filter_module.so
- ngx_http_geoip2_module.so
- ngx_http_security_headers_module.so
- ngx_http_waf_module.so
- ngx_http_brotli_static_module.so
- ngx_http_headers_more_filter_module.so
- ngx_http_sysguard_module.so
- ngx_pagespeed.so
- ngx_http_cookie_flag_filter_module.so
- ngx_http_modsecurity_module.so
- ngx_http_testcookie_access_module.so
- ngx_http_cookie_limit_req_module.so
- ngx_http_naxsi_module.so
- ngx_http_vhost_traffic_status_module.so

__Pre Existing Forked
- Nagios with SSL auto signed certificate (vanilla source available as dynamic module - needs checking)
- Nginx 1.18.0.8
- PHP 7.3 with FPM and FCGI wrapper (will update to 8.0|8.1 in near future)
- Squid proxy (disabled by default)->(+need to check)
- Squidguard with blacklists (disabled by default)->(+need to check)

## Description

This is a script to automatically install and configure Nagios, Nginx and SSL auto signed certificate for Nagios, PHP 7.3 with FPM, and all the required dependency to work on Debian 10.

You can choose whenever you want to install, either apt installation or directly from sources with custom configuration or compilation flags.

Nagios don't seem to have any apt packages available anymore, so no other choice than downloading the tarball.

__Cons of the manual install__:
- Some dependencies may be slow to download.
- They're aren't by default any `nginx.service` file so the basic `systemctl` command won't work. That's why a `nginx.service` file is provided.
- The $PATH needs to be updated to keep track of the nginx binary path, and since you can't source in a subshell to export an env variable, that's the purpose of `path.sh` which is called by the `install.sh`

The `addhost.sh` is a CLI script to add a new host in Nagios.

Squid and Squiguard are optional and disabled by default. To enable Squid and Squidguard installation, simply uncomment the corresponding install lines in `install.sh`

**Warning: Before doing anything, check that the `echo $PATH` is correct. There seems to be a bug or a major change on Debian 10 Buster for that.**
Otherwise `export PATH=$PATH:/usr/sbin`.

### Nagios

*Nagios path is by default in `/usr/local` and not `/etc` since it's compiled by sources.*

Path        `/usr/local/nagios`

Config      `/usr/local/nagios/etc/nagios.conf`

Host config `/usr/local/nagios/etc/objects/*`

Reload      `systemctl reload nagios`


__Credentials by default__:

User:     `nagiosadmin`

Password: `nagiosadmin`

**Be sure to test in private navigation mode to disable cache or do a Ctrl+F5 each time to reload the cache.**

Basic Auth with htpasswd is mandatory for Nagios, otherwise you won't have access to the hosts page.

Don't deny the `X-Frame-Options` header in Nginx configuration file for Nagios, otherwise you'll break the webpage.

Also, `ssl_stapling off;` and `ssl_stapling_verify off;` are disabled to avoid some errors since the certificate is auto signed for local test purpose.

Enable both for prod and don't forget to change the password.

### Nginx

Port      `80, 443`

Config    `/etc/nginx/nginx.conf`

Sites     `/etc/nginx/sites-available`

Reload    `systemctl reload nginx` or `nginx -s reload`

The `site-enabled` folder only contains symbolics links to `sites-available`.

To disable a site, simply delete the link then reload.

### Squid

Port   `3128`

Config  `/etc/squid.conf`

Reload  `systemctl reaload squid`


To test: *(I denied google.com on purpose to test)*

`curl -x localhost:3128 -I https://www.google.com`

and check the redirections or 403 HTTP return codes.


### SquidGuard

Config     `/etc/squidguard/squidGuard.conf`

Blacklists `/var/lib/squidguard/db`

Reload     `squidguard -bdC all && squid -k reconfigure`

**Watch out for the capital G letter in Squid__G__uard, she seems to not be everywhere the same**

To plug Squidguard to Squid, add `url_rewrite_program` in `squid.conf` then restart the Squid daemon.

Every time you'll add or update a blacklist, you need to regenerate .db files with `squidguard -bdC all` then `squid -k reconfigure` to reconfigure Squid.

To test:
`echo "http://www.youtube.com / - - GET" | squidGuard -d`
and check the redirections or 403 HTTP return codes.
