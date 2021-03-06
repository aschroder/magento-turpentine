# Nexcess.net Turpentine Extension for Magento

Turpentine is a Magento extension to improve Magento's compatibility with
[Varnish](https://www.varnish-cache.org/), a very-fast caching reverse-proxy. By
default, Varnish doesn't cache requests with cookies and Magento sends the
*frontend* cookie with every request causing a (near) zero hit-rate for Varnish's cache.
Turpentine provides Varnish configuration files (VCLs) to work with Magento and
modifies Magento's behaviour to significantly improve the cache hit rate.

## Features

 - Full Magento Page Caching
 - Compatible with Varnish versions 2.1 and 3.0
 - Requires very little configuration for impressive results
 - Able to apply new Varnish VCL (configurations) on the fly, without
 restarting/changing Varnish's config files
 - Cache purging by URL and content type
 - Exclude URL paths, request parameters (__SID, __store, etc), and/or cookies
 from caching
 - Configure cache TTL by URL
 - Ability to force static asset (css, js, etc) caching even after an action
 that disables caching for a client
 - Supports multiple Varnish instances for clustered usage

## Requirements

 - Magento Community Edition 1.6+ (earlier versions may work but have not been
 tested) or Magento Enterprise Edition 1.11+ (very little EE testing has been done)
 - Varnish 2.1+

## Installation

See the [Installation](/nexcess/magento-turpentine/wiki/Installation) page.

## Known Issues

 - Logging and statistics will show all requests as coming from the same IP address
 (usually localhost/127.0.0.1). It should be possible to work around this using
 Apache's [mod_remoteip](http://httpd.apache.org/docs/trunk/mod/mod_remoteip.html)
