#!/usr/bin/env perl6-j

use lib 'lib';
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

$s.register(sub ($connection, $request) {
  $request.data.say;
  $connection.send("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\npoop\n{$request.method}|{$request.version}|{$request.uri}\n{$request.data}");
  return True;
});

$s.listen;


sleep 500;
