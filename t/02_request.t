#!/usr/bin/env perl6-j

use lib 't/lib';
use HTTP::Server::Async;
use Test;

plan 2;

my $s = HTTP::Server::Async.new;


my Str $timetest = time.Str;
$s.register(sub ($req,$res,$n) {
  $res.close($timetest);
});
$s.listen;

my $host = '127.0.0.1';
my $port = 8080;
 
my $client = IO::Socket::INET.new(:$host, :$port);

$client.send("GET / HTTP/1.0\r\n\r\n");
my $data;
while (my $str = $client.recv) {
  $data ~= $str;
}
$client.close;

ok $data ~~ rx/^^ 'XYZ: ABC' $$/, 'Testing for XYZ Middleware Header';
ok $data ~~ rx/^^ "$timetest" $$/, "Testing for $timetest";

