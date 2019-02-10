#!/usr/bin/env perl6

use lib 'examples/lib';
use HTTP::Server::Async;
use HTTP::Server::Async::Plugins::Middleware::Hijack;

my $s = HTTP::Server::Async.new;
$s.middleware(&hijack);

#note that these handlers are never called, check 
#  <repo>/examples/lib/HTTP/Server/Async/Plugins/Middleware/Hijack.pm6
#  for more info
$s.handler(sub ($request, $response) {
  $response.status = 404;
  'Registered sub called.'.say;
  #this is never called!
  $response.write('Registered Sub');
  $response.close;
  False; #Don't continue
});

$s.handler(sub ($request,$response) {
  $response.status = 404;
  'Registered sub2 called.'.say;
  #this is never called!
  $response.write('Registered Sub');
  $response.close;
  True; #Continue if there is another
});

say "listening";
await $s.listen;
