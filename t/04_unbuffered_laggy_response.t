#!/usr/bin/env perl6

use lib 't/lib';
use starter;
use Test;

plan 3;

my $s = srv(:buffered(False));

$s.register(sub ($request, $response, $n) {
  start { 
    $response.write('chunk 1');
    sleep 5;
    $n();
  };
});
$s.register(sub ($request, $response, $n) {
  $response.headers<Connection> = 'close';
  $response.close('chunk 2');
});
$s.listen;

my $client = req;
$client.send("GET / HTTP/1.0\r\n\r\n");
my $flag = 0;
while (my $str = $client.recv) {
  if $str.match(/ 'chunk 1' /) {
    $flag = time;
    ok True, 'chunk 1';
  } elsif $flag > 0 && $str.match(/ 'chunk 2' /) {
    $flag = time - $flag;
    ok True, 'chunk 2';
    ok $flag > 1 && $flag < 10, "Time lag ($flag)";
  }
}
$client.close;

# vi:syntax=perl6
