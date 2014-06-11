#!/usr/bin/env perl6-j

use lib 'lib';
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

$s.register(sub ($request, $response) {
  $response.headers<Content-Type> = 'text/plain';
  $response.status = 200;
  $response.write("write 1\n");
#  $response.close("poop\n{$request.method}|{$request.version}|{$request.uri}\n{$request.data}");
  return True;
});

$s.register(sub ($request, $response) {
  'killer'.say;
  $response.close;
});

$s.listen;


sleep 500;
