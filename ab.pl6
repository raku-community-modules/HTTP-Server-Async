#!/usr/bin/env perl6

use lib 'lib';
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;
my $d = -1;
$s.register(sub ($req, $res, $next) {
  my $j = $d++ + 1;
  "here $j".say;
  $res.headers<Content-Type> = 'text/plain';
  $res.status = 200;
  $res.write("Hello ");
  $res.close("world!");
  "end $d".say;
});

$s.listen;
sleep 500;
