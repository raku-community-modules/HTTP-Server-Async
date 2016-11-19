#!/usr/bin/env perl6

use lib $*PROGRAM.parent.parent.child('lib').Str;

use HTTP::Server::Async;


my $server = HTTP::Server::Async.new;

$server.handler(sub ($request,$response) {
  try {
    if $request.uri.match(/ ^ '/' [ '?' | $ ] /) {
      '[INFO] Serving /'.say;
      $response.write($request.uri);
      $response.write($request.data);
      $response.close;
      return False;
    }
    CATCH { .say; };
  }
  'next'.say;
  True;
});

$server.handler(sub ($request,$response) {
  '[INFO] Serving <404>'.say;
  try {
    $response.status = 404;
    $response.write('404: ' ~ $request.uri ~ ' not found.');
    $response.close;
    CATCH { .say; }
  };
  False;
});

$server.listen(True);
