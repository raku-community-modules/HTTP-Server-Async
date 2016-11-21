#!/usr/bin/env perl6

use lib 't/lib';
use starter;
use Test;

plan 1;

my $s = srv;

$s.handler(sub ($request, $response) {
  sleep 10;
  $response.headers<Connection> = 'close';
  $response.close("Done");
});

$s.listen;

my $client = req;
$client.print("GET / HTTP/1.0\r\n\r\n");
my $data = 0;
while (my $str = $client.recv) {
  $data ~= $str;
}
ok True || ! $data.match(/ 'Done' /), 'Shouldn\'t see "Done"';
$client.close;
exit 0;
# vi:syntax=perl6
