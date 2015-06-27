#!/usr/bin/env perl6

use lib 't/lib';
use starter;
use Test;

plan 11;

my $s = srv;
isa-ok $s, HTTP::Server::Async;
is $s.responsestack.elems, 0, 'Response stack contains no elements yet';

$s.register(sub ($req,$res,$n) {
  start {
    $res.write('buffered');
    sleep 2;
    $n();
  };
});

$s.register(sub ($request, $response, $n) {
  $response.headers<Content-Type> = 'text/plain';
  $response.headers<Connection>   = 'close';
  $response.status = 200;
  $response.unbuffer;
  start {
    sleep 2;
    $response.close("Hello world!");
  };
});
ok $s.responsestack.elems, 'Response stack contains elements';
isa-ok $s.responsestack[0], Sub;

$s.listen;

 
my $client = req;
isa-ok $client, IO::Socket::INET;
is $client.host, host, 'IO::Socket::INET correct host';
is $client.port, port, 'IO::Socket::INET correct port';

$client.send("GET / HTTP/1.0\r\n\r\n");
my $ret = '';
my $recv;
while (my $str = $client.recv) {
  if ($str.match(/ ^^ buffered $$ /)) {
    $recv = time;
  }
  if ($str.match(/ ^^ 'Hello world!' $$ /)) {
    $recv = time - $recv;
  } 
  $ret ~= $str;
}
$client.close;
ok $ret.match(/ ^^ 'HTTP/1.1 200 OK' $$ /), 'HTTP Status Code: 200';
ok $ret.match(/ ^^ 'Content-Type: text/plain' $$ /), 'Content-Type';
ok $ret.match(/ ^^ 'bufferedHello world!' $$ /), "Content: bufferedHello World!";
ok $recv == 2, "Time between flush and write ~2";

# vi:syntax=perl6
