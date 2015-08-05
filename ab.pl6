#!/usr/bin/env perl6

use lib 'lib';
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

my $requests = 0;
$s.handler(sub ($req, $res) {
  $res.headers<Content-Type> = 'text/plain';
  $res.status = 200;
  $res.write("Hello ");
  $res.close("world ({$requests++})!\n");
});

$s.listen(True);
