#!/usr/bin/env perl6-j

use HTTP::Server::Async;
use Test;

plan 3;

my $s = HTTP::Server::Async.new;

$s.register(sub ($request, $response) {
  $response.headers<Content-Type> = 'text/plain';
  $response.status = 200;
  $response.write("");
  $response.close("Hello world!");
  return True;
});

$s.listen;

my $host = '127.0.0.1';
my $port = 8080;
 
my $client = IO::Socket::INET.new(:$host, :$port);
$client.send("GET / HTTP/1.0\r\n\r\n");
my @data;
while (my $str = $client.recv) {
  @data.push($str);
}
$client.close;

ok @data[0] = "200 OK\r\n";
ok @data[1] = "Content-Type: text/plain\r\nContent-Length: 12\r\n\r\n";
ok @data[2] = "Hello world!";

