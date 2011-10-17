# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket;

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 2);

#no_diff();
#no_long_string();
#master_on();
#workers(2);
run_tests();

__DATA__

=== TEST 1: read buffered body
--- config
    location = /test {
        content_by_lua '
            ngx.req.read_body()
            ngx.say(ngx.var.request_body)
        ';
    }
--- request
POST /test
hello, world
--- response_body
hello, world



=== TEST 2: read buffered body (timed out)
--- config
    client_body_timeout 1ms;
    location = /test {
        content_by_lua '
            ngx.req.read_body()
            ngx.say(ngx.var.request_body)
        ';
    }
--- raw_request eval
"POST /test HTTP/1.1\r
Host: localhost\r
Content-Length: 100\r
Connection: close\r

hello, world"
--- response_body:
--- error_code:



=== TEST 3: read buffered body and then subrequest
--- config
    location /foo {
        echo -n foo;
    }
    location = /test {
        content_by_lua '
            ngx.req.read_body()
            local res = ngx.location.capture("/foo");
            ngx.say(ngx.var.request_body)
            ngx.say("sub: ", res.body)
        ';
    }
--- request
POST /test
hello, world
--- response_body
hello, world
sub: foo



=== TEST 4: first subrequest and then read buffered body
--- config
    location /foo {
        echo -n foo;
    }
    location = /test {
        content_by_lua '
            local res = ngx.location.capture("/foo");
            ngx.req.read_body()
            ngx.say(ngx.var.request_body)
            ngx.say("sub: ", res.body)
        ';
    }
--- request
POST /test
hello, world
--- response_body
hello, world
sub: foo



=== TEST 5: read_body not allowed in set_by_lua
--- config
    location /foo {
        echo -n foo;
    }
    location = /test {
        set_by_lua $has_read_body '
            return ngx.req.read_body and "defined" or "undef"
        ';
        echo "ngx.req.read_body: $has_read_body";
    }
--- request
GET /test
--- response_body
ngx.req.read_body: undef



=== TEST 6: read_body not allowed in set_by_lua
--- config
    location /foo {
        echo -n foo;
    }
    location = /test {
        set $bool '';
        header_filter_by_lua '
             ngx.var.bool = (ngx.req.read_body and "defined" or "undef")
        ';
        content_by_lua '
            ngx.send_headers()
            ngx.say("ngx.req.read_body: ", ngx.var.bool)
        ';
    }
--- request
GET /test
--- response_body
ngx.req.read_body: undef

