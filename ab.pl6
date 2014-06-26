#!/usr/bin/env perl6

use lib 'lib';
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

$*SCHEDULER = ThreadPoolScheduler.new(:max_threads(1000));

$s.register(sub ($req, $res, $next) {
  $res.headers<Content-Type> = 'text/plain';
  $res.status = 200;
  $res.write("Hello ");
  $res.close("world!");
});

$s.listen;
'listen'.say;
$s.block;
