#!/usr/bin/env perl6

use lib 't/lib';
use starter;
use Test;

plan 11;

my $s = srv;
isa-ok $s, HTTP::Server::Async;
is $s.responsestack.elems, 0, 'Response stack contains no elements yet';

$s.register(sub ($req,$res,$n) {
  start {
    sleep 2;
    $n();
  };
});

$s.register(sub ($request, $response, $n) {
  $response.headers<Content-Type> = 'text/plain';
  $response.headers<Connection>   = 'close';
  $response.status = 200;
  $response.write("");
  $response.close("Hello world!");
});
ok $s.responsestack.elems, 'Response stack contains elements';
isa-ok $s.responsestack[0], Sub;

$s.listen;

 
my $client = req;
isa-ok $client, IO::Socket::INET;
is $client.host, host, 'IO::Socket::INET correct host';
is $client.port, port, 'IO::Socket::INET correct port';

$client.send("GET / HTTP/1.0\r\n\r\n");
my $ret = '';
while (my $str = $client.recv) {
  $ret ~= $str;
}
$client.close;
ok $ret.match(/ ^^ 'HTTP/1.1 200 OK' $$ /), 'HTTP Status Code: 200';
ok $ret.match(/ ^^ 'Content-Type: text/plain' $$ /), 'Content-Type';
ok $ret.match(/ ^^ 'Content-Length: 12' $$ /), 'Content-Length';
ok $ret.match(/ ^^ 'Hello world!' $$ /), "Content: Hello World!";

# vi:syntax=perl6
