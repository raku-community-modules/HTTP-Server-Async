#!/usr/bin/env perl6-j

use lib 'lib';
use HTTP::Server::Async;
use Test;

plan 11;

my $host = '127.0.0.1';
my $port = (6000..8000).pick;
my $s = HTTP::Server::Async.new(:$host, :$port);
isa_ok $s, HTTP::Server::Async;
is $s.responsestack.elems, 0, 'Response stack contains no elements yet';

$s.register(sub ($req,$res,$n) {
  start {
    sleep 2;
    $n();
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

 
my $client = IO::Socket::INET.new(:$host, :$port) or die 'couldn\'t connect';
isa_ok $client, IO::Socket::INET;
is $client.host, $host, 'IO::Socket::INET correct host';
is $client.port, $port, 'IO::Socket::INET correct port';

$client.send("GET / HTTP/1.0\r\n\r\n");
my $ret;
while (my $str = $client.recv) {
  $ret ~= $str;
}
$client.close;
ok $ret.match(/ ^^ 'HTTP/1.1 200 OK' $$ /), 'HTTP Status Code: 200';
ok $ret.match(/ ^^ 'Content-Type: text/plain' $$ /), 'Content-Type';
ok $ret.match(/ ^^ 'Content-Length: 12' $$ /), 'Content-Length';
ok $ret.match(/ ^^ 'Hello world!' $$ /), "Content: Hello World!";

# vi:syntax=perl6
