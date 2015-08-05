#!/usr/bin/env perl6

use lib 't/lib';
use starter;
use Test;

plan 1;

my $s = srv;
$s.listen;

$s.handler(sub ($request, $response) {
  $response.headers<Connection> = 'close';
  $response.headers<Content-Type> = 'text/plain';
  $response.status = 404;
  $response.write("");
  $response.close("Not found");
});

my $client = req;
$client.print("GET / HTTP/1.0\r\n\r\n");
my $ret;
while (my $str = $client.recv) {
  $ret ~= $str;
}
$client.close;
ok $ret.match(/ ^^ 'HTTP/1.1 404 Not Found' $$ /), 'HTTP Status Code: 404';
exit 0;

# vi:syntax=perl6
