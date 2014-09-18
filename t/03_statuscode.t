#!/usr/bin/env perl6-j

use HTTP::Server::Async;
use Test;

plan 1;

my $s = HTTP::Server::Async.new;
$s.register(sub ($request, $response, $n) {
  $response.headers<Content-Type> = 'text/plain';
  $response.status = 404;
  $response.write("");
  $response.close("Not found");
});
$s.listen;

my $host = '127.0.0.1';
my $port = 8080;
my $client = IO::Socket::INET.new(:$host, :$port);
$client.send("GET / HTTP/1.0\r\n\r\n");
my $ret;
while (my $str = $client.recv) {
  $ret ~= $str;
}
$client.close;
ok $ret.match(/ ^^ 'HTTP/1.1 404 Not Found' $$ /), 'HTTP Status Code: 404';

# vi:syntax=perl6
