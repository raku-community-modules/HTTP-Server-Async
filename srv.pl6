#!/usr/bin/env perl6-j

use lib 'lib';
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

$s.register(sub ($request, $response) {
  $response.headers<Content-Type> = 'text/plain';
  $response.status = 200;
  $response.close('');
  return True;
});

$s.listen;


sleep 500;
