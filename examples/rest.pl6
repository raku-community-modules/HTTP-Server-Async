#!/usr/bin/env perl6

use lib $*PROGRAM.parent.parent.child('lib').Str;

use HTTP::Server::Async;

my $server = HTTP::Server::Async.new;

$server.handler(sub ($request,$response) {
  if $request.uri eq '/endpoint1' {
    $response.write('{ "endpoint": "1" }');
    $response.close;
    return False;
  }
  True;
});

$server.handler(sub ($request,$response) {
  if $request.uri eq '/endpoint2' {
    $response.write('{ "endpoint": "2" }');
    $response.close;
    return False;
  }
  True;
});

$server.handler(sub ($request,$response) {
  $response.status = 404;
  $response.write('404: ' ~ $request.uri ~ ' not found.');
  $response.close;
  False;
});

$server.listen(True);
