#!/usr/bin/env perl6

use HTTP::Server::Async;

my $server = HTTP::Server::Async.new;

$server.register(sub ($request,$response, $next) {
  ('[INFO] ' ~ $request.perl).say;
  try {
    if $request.uri.match(/ ^ '/' [ '?' | $ ] /) {
      '[INFO] Serving /'.say;
      $response.write($request.uri);
      $response.write($request.data);
      $response.close;
      return;
    }
    CATCH { .say; };
  }
  'next'.say;
  $next();
});

$server.register(sub ($request,$response,$next) {
  '[INFO] Serving <404>'.say;
  try {
    $response.status = 404;
    $response.write('404: ' ~ $request.uri ~ ' not found.');
    $response.close;
    CATCH { .say; }
  };
});

$server.listen;
$server.block;
