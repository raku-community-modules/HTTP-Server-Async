#!/usr/bin/env perl6

use lib 'lib';
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;
my $d = -1;

$*SCHEDULER = ThreadPoolScheduler.new;

$*SCHEDULER.uncaught_handler = sub ($e) {
  $e.say;
  $e.resume;
};
$*SCHEDULER.cue: { "load: {$*SCHEDULER.loads}".say; }, :every(1);

$s.register(sub ($req, $res, $next) {
  my $j = $d++ + 1;
  $res.headers<Content-Type> = 'text/plain';
  $res.status = 200;
  $res.write("Hello ");
  $res.close("world!");
  "end $j".say;
});

$s.listen;
'listen'.say;
$s.block;
