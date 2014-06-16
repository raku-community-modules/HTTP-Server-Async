#!/usr/bin/env perl6

use HTTP::Server::Async;

my $server = HTTP::Server::Async.new;

$server.register(sub ($request,$response) {
  ('[INFO] ' ~ $request.perl).say;
  if $request.uri eq '/' {
    $response.write($request.data);
    $response.close;
    return True;
  }
  return False;
});

$server.register(sub ($request,$response) {
  $response.status = 404;
  $response.write('404: ' ~ $request.uri ~ ' not found.');
  $response.close;
  return True;
});

$server.listen;
$server.block;
