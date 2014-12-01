#!/usr/bin/env perl6

use lib '../lib';
use lib 'lib';
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;
$s.middleware('HTTP::Server::Async::Plugins::Middleware::Hijack');

#note that these handlers are never called, check 
#  <repo>/examples/lib/HTTP/Server/Async/Plugins/Middleware/Hijack.pm6
#  for more info
$s.register(sub ($request, $response, $last) {
  $response.status = 404;
  'Registered sub called.'.say;
  #this is never called!
  $response.write('Registered Sub');
  $response.close;
  $last(True); #Don't continue
});

$s.register(sub ($request,$response,$last) {
  $response.status = 404;
  'Registered sub2 called.'.say;
  #this is never called!
  $response.write('Registered Sub');
  $response.close;
  $last(False); #Continue if there is another
});

$s.listen;
say "listening";
$s.block;
