#!/usr/bin/env perl6-j

use lib 'lib';
use lib 't/lib';
use HTTP::Server::Async;
use Test;
plan 1;

my $s = HTTP::Server::Async.new;
$s.listen;

my $host = '127.0.0.1';
my $port = 8080;
 
my $client = IO::Socket::INET.new(:$host, :$port);
$client.send("GET / HTTP/1.0\r\n\r\n");
my $data;
while (my $str = $client.recv) {
  say "$str";
  $data ~= $str;
}
$client.close;

ok $data ~~ rx/^^ 'XYZ: ABC' $$/, 'Testing for XYZ Middleware Header';
