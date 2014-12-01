#!/usr/bin/env perl6

use lib 'lib';
use lib '../lib';
use HTTP::Server::Async;

my $server = HTTP::Server::Async.new;

$server.register(sub ($request,$response, $next) {
  if $request.uri eq '/endpoint1' {
    $response.write('{ "endpoint": "1" }');
    $response.close;
    return;
  }
  $next();
});

$server.register(sub ($request,$response, $next) {
  if $request.uri eq '/endpoint2' {
    $response.write('{ "endpoint": "2" }');
    $response.close;
    return;
  }
  $next();
});

$server.register(sub ($request,$response, $next) {
  $response.status = 404;
  $response.write('404: ' ~ $request.uri ~ ' not found.');
  $response.close;
});

$server.listen;
$server.block;
