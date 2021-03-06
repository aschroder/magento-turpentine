## Nexcessnet_Turpentine Varnish v2 VCL Template

## Backends

{{default_backend}}

{{admin_backend}}

## Custom Subroutines
sub remove_cache_headers {
    remove beresp.http.Set-Cookie;
    remove beresp.http.Cache-Control;
    remove beresp.http.Expires;
    remove beresp.http.Pragma;
    remove beresp.http.Cache;
    remove beresp.http.Age;
}

## Varnish Subroutines

sub vcl_recv {
    if (req.restarts == 0) {
        if (req.http.X-Forwarded-For) {
            set req.http.X-Forwarded-For =
                req.http.X-Forwarded-For ", " client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
    }

    if (req.request != "GET" &&
            req.request != "HEAD" &&
            req.request != "PUT" &&
            req.request != "POST" &&
            req.request != "TRACE" &&
            req.request != "DELETE" &&
            req.request != "OPTIONS") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }

    if (req.request != "GET" && req.request != "HEAD") {
        /* We only deal with GET and HEAD by default */
        return (pass);
    }

    {{normalize_encoding}}
    {{normalize_user_agent}}
    {{normalize_host}}

    set req.http.X-Opt-Enable-Caching = "{{enable_caching}}";
    set req.http.X-Opt-Force-Static-Caching = "{{force_cache_static}}";
    set req.http.X-Opt-Enable-Get-Excludes = "{{enable_get_excludes}}";
    set req.http.X-Opt-Set-Initial-Cookie = "{{set_initial_cookie}}";

    if (req.http.X-Opt-Enable-Caching !~ "true") {
        return (pass);
    }
    if (req.url ~ "{{url_base_regex}}{{admin_frontname}}") {
        set req.backend = admin;
        return (pass);
    }
    if (req.url ~ "{{url_base_regex}}") {
        if (req.http.X-Opt-Force-Static-Caching ~ "true" &&
                req.url ~ ".*\.(?:{{static_extensions}})(?=\?|$)") {
            remove req.http.Cookie;
            return (lookup);
        }
        if (req.url ~ "{{url_base_regex}}(?:{{url_excludes}})") {
            return (pass);
        }
        if (req.http.Cookie ~ "{{cookie_excludes}}") {
            return (pass);
        }
        if (req.http.X-Opt-Enable-Get-Excludes ~ "true" &&
                req.url ~ "(?:[?&](?:{{get_param_excludes}})(?=[&=]|$))") {
            return (pass);
        }
        if (req.http.X-Opt-Set-Initial-Cookie ~ "true") {
            if (req.http.Cookie && req.http.Cookie ~ "frontend=") {
                set req.http.X-Varnish-Cookie = req.http.Cookie;
                remove req.http.Cookie;
                return (lookup);
            } else {
                return (pass);
            }
        } else {
            remove req.http.Cookie;
            return (lookup);
        }
    }
    # else it's not part of magento so do default handling (doesn't help
    # things underneath magento but we can't detect that)
}

sub vcl_pipe {
    set req.http.Connection = "close";
    return (pipe);
}

# sub vcl_pass {
#     return (pass);
# }

sub vcl_hash {
    set req.hash += req.url;
    if (req.http.Host) {
        set req.hash += req.http.Host;
    } else {
        set req.hash += server.ip;
    }
    if (req.http.X-Normalized-User-Agent) {
        set req.hash += req.http.X-Normalized-User-Agent;
    }
    if (req.http.Accept-Encoding) {
        set req.hash += req.http.Accept-Encoding;
    }
    return (hash);
}

# sub vcl_hit {
#     return (deliver);
# }
#
# sub vcl_miss {
#     return (fetch);
# }
#

sub vcl_fetch {
    set req.grace = {{grace_period}}s;

    if (req.http.X-Opt-Force-Static-Caching ~ "true" &&
            bereq.url ~ ".*\.(?:{{static_extensions}})(?=\?|$)") {
        call remove_cache_headers;
        set beresp.cacheable = true;
        set beresp.ttl = {{static_ttl}}s;
    } else if (req.http.Cookie ~ "{{cookie_excludes}}" ||
        beresp.http.Set-Cookie ~ "{{cookie_excludes}}") {
        return (deliver);
    } else if (beresp.http.X-Varnish-Bypass) {
        set beresp.ttl = {{grace_period}}s;
        return (pass);
    } else {
        if (req.http.X-Opt-Set-Initial-Cookie ~ "true") {
            if (req.http.X-Varnish-Cookie) {
                call remove_cache_headers;
                set beresp.cacheable = true;
                {{url_ttls}}
            }
        } else {
            call remove_cache_headers;
            set beresp.cacheable = true;
            {{url_ttls}}
        }
    }
}

# sub vcl_fetch {
#     if (beresp.ttl <= 0s ||
#         beresp.http.Set-Cookie ||
#         beresp.http.Vary == "*") {
# 		/*
# 		 * Mark as "Hit-For-Pass" for the next 2 minutes
# 		 */
# 		set beresp.ttl = 120 s;
# 		return (hit_for_pass);
#     }
#     return (deliver);
# }

#https://www.varnish-cache.org/trac/wiki/VCLExampleHitMissHeader
sub vcl_deliver {
    set resp.http.X-Opt-Debug-Headers = "{{debug_headers}}";
    if (resp.http.X-Opt-Debug-Headers ~ "true") {
        if (obj.hits > 0) {
            set resp.http.X-Varnish-Hits = "HIT: " obj.hits;
        } else {
            set resp.http.X-Varnish-Hits = "MISS";
        }
    } else {
        #remove Varnish fingerprints
        remove resp.http.X-Varnish;
        remove resp.http.Via;
        remove resp.http.X-Powered-By;
        remove resp.http.Server;
        remove resp.http.Age;
    }
    remove resp.http.X-Opt-Debug-Headers;
}

sub vcl_error {
    remove obj.http.Server;
}

# sub vcl_error {
#     set obj.http.Content-Type = "text/html; charset=utf-8";
#     set obj.http.Retry-After = "5";
#     synthetic {"
# <?xml version="1.0" encoding="utf-8"?>
# <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
#  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
# <html>
#   <head>
#     <title>"} + obj.status + " " + obj.response + {"</title>
#   </head>
#   <body>
#     <h1>Error "} + obj.status + " " + obj.response + {"</h1>
#     <p>"} + obj.response + {"</p>
#     <h3>Guru Meditation:</h3>
#     <p>XID: "} + req.xid + {"</p>
#     <hr>
#     <p>Varnish cache server</p>
#   </body>
# </html>
# "};
#     return (deliver);
# }
#
# sub vcl_init {
# 	return (ok);
# }
#
# sub vcl_fini {
# 	return (ok);
# }
