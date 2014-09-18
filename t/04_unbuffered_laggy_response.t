#!/usr/bin/env perl6-j

use HTTP::Server::Async;
use Test;

plan 3;

my $s = HTTP::Server::Async.new(:buffered(False));

$s.register(sub ($request, $response, $n) {
  start { 
    $response.write('chunk 1');
    sleep 5;
    $n();
  };
});
$s.register(sub ($request, $response, $n) {
  $response.close('chunk 2');
});
$s.listen;

my $host = '127.0.0.1';
my $port = 8080;
my $client = IO::Socket::INET.new(:$host, :$port);
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
