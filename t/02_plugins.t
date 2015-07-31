#!/usr/bin/env perl6

use lib 't/lib';
use starter;
use Test;

plan 2;

my $s = srv;

my Str $timetest = time.Str;
$s.middleware('HTTP::Server::Async::Plugins::Middleware::Inject');
$s.register(sub ($req,$res,$n) {
  $res.headers<Connection> = 'close';
  $res.close($timetest);
});
$s.listen;

my $client = req;

$client.print("GET / HTTP/1.0\r\n\r\n");
my $data;
while (my $str = $client.recv) {
  $data ~= $str;
}
$client.close;

ok $data ~~ rx/^^ 'XYZ: ABC' $$/, 'Testing for XYZ Middleware Header';
ok $data ~~ rx/^^ "$timetest" $$/, "Testing for $timetest";

