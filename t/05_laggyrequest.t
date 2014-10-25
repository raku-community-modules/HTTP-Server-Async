#!/usr/bin/env perl6-j

use lib 'lib';
use HTTP::Server::Async;
use Test;

plan 1;

my $s = HTTP::Server::Async.new(:buffered(False));

$s.register(sub ($request, $response, $n) {
  $response.close('Hello');
});
$s.listen;

my $host = '127.0.0.1';
my $port = 8080;
my $client = IO::Socket::INET.new(:$host, :$port);
$client.send("GET / HTTP/1.0\r\n");
sleep 10;
$client.send("\r\n");
my $data = 0;
while (my $str = $client.recv) {
  $data ~= $str;
}
ok $data.match(/'Hello'/), 'Response';
$client.close;

# vi:syntax=perl6
