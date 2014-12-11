#!/usr/bin/env perl6-j

use lib 't/lib';
use starter;
use Test;

plan 1;

my $s = srv(:buffered(False));

$s.register(sub ($request, $response, $n) {
  $response.headers<Connection> = 'close';
  $response.close('Hello');
});
$s.listen;

my $client = req;
$client.send("GET / HTTP/1.0\r\n");
sleep 10;
$client.send("\r\n");
my $data;
while (my $str = $client.recv) {
  $data ~= $str;
}
ok $data.match(/'Hello'/), 'Response';
$client.close;

# vi:syntax=perl6
