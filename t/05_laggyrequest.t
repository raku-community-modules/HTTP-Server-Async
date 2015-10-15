#!/usr/bin/env perl6

use lib 't/lib';
use starter;
use Test;

plan 1;

my $s = srv;

$s.handler(sub ($request, $response) {
  $response.unbuffer;
  $response.headers<Connection> = 'close';
  $response.close('Hello');
});

$s.listen;

my $client = req;
$client.print("GET / HTTP/1.0\r\n");
sleep 5;
$client.print("\r\n");
my $data;
while (my $str = $client.recv) {
  $data ~= $str;
}
ok $data.match(/'Hello'/), 'Response';
$client.close;

# vi:syntax=perl6
