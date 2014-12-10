#!/usr/bin/env perl6

use lib 'lib';
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

#$*SCHEDULER = ThreadPoolScheduler.new(:max_threads(1000));

my $requests = 0;
$s.register(sub ($req, $res, $next) {
  try {
    $res.headers<Content-Type> = 'text/plain';
    $res.status = 200;
    $res.write("Hello ");
    $res.close("world ({$requests++})!\n");
    "{$requests}".say;
  };
});

$s.listen;
'listen'.say;
$s.block;
