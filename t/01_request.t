#!/usr/bin/env perl6-j

use HTTP::Server::Async;
use Test;

plan 10;

my $s = HTTP::Server::Async.new;
isa_ok $s, HTTP::Server::Async;
is $s.responsestack.elems, 0, 'Response stack contains no elements yet';

$s.register(sub ($req,$res,$n) {
  start {
    sleep 2;
    $n.();
  };
});

$s.register(sub ($request, $response, $n) {
  $response.headers<Content-Type> = 'text/plain';
  $response.status = 200;
  $response.write("");
  $response.close("Hello world!");
});
ok $s.responsestack.elems, 'Response stack contains elements';
isa_ok $s.responsestack[0], Sub;

$s.listen;

my $host = '127.0.0.1';
my $port = 8080;
 
my $client = IO::Socket::INET.new(:$host, :$port);
isa_ok $client, IO::Socket::INET;
is $client.host, $host, 'IO::Socket::INET correct host';
is $client.port, $port, 'IO::Socket::INET correct port';

$client.send("GET / HTTP/1.0\r\n\r\n");
my @data;
while (my $str = $client.recv) {
  @data.push($str);
}
$client.close;

is @data[0], "HTTP/1.1 200 OK\r\n", "Code: 200";
is @data[1], "Content-Type: text/plain\r\nContent-Length: 12\r\n\r\n", "Content-type correct";
is @data[2], "Hello world!", "Content: Hello World!";

