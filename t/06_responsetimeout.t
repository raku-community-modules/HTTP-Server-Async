#!/usr/bin/env perl6

use lib 't/lib';
use starter;
use Test;

plan 1;

my $s = srv(:timeout(3));

$s.register(sub ($request, $response, $n) {
  sleep 10;
  $response.headers<Connection> = 'close';
  $response.close("Done");
  $n();
});
$s.listen;

my $client = req;
$client.send("GET / HTTP/1.0\r\n\r\n");
my $data = 0;
while (my $str = $client.recv) {
  $data ~= $str;
}
ok ! $data.match(/ 'Done' /), 'Shouldn\'t see "Done"';
$client.close;

# vi:syntax=perl6
