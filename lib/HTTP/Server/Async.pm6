#!/usr/bin/env perl6

use HTTP::Server::Async::Request;
use HTTP::Server::Async::Response;

class HTTP::Server::Async {
  has $.host          = '127.0.0.1';
  has $.port          = 8080;
  has $.debug         = 1;
  has Bool $.buffered = True;
  has $!prom;
  has $!conn;
  has @.responsestack;

  method listen() {
    $*SCHEDULER.thread_max.say;
    my $num = 0;
    $!prom  = Promise.new;
    $!conn  = IO::Socket::Async.listen($.host,$.port,) or die "Couldn't listen on port: $.port";
    $!conn.tap(-> $connection {
      my $data     = '';
      my $request  = HTTP::Server::Async::Request.new;
      my $response = HTTP::Server::Async::Response.new(:$connection, :$.buffered); 
      my $tap      = $connection.chars_supply.tap({ 
        $data ~= $_;
        self!respond($request, $response) if so $request.parse($data);
      });
    }, quit => {
      $!prom.vow.keep(1);
    });
  }

  method block {
    await $!prom;
  }

  method register(Callable $sub) {
    @.responsestack.push($sub);
  }

  method !respond($req, $res) {
    my $promise;
    for @.responsestack -> $sub {
      try {
        $promise = Promise.new;
        $sub.($req, $res, sub { $promise.keep(True); } );
        await Promise.anyof($promise, $res.promise);
        last if $res.promise.status == Kept;
      };
    }

    try {
      $res.close if $res.promise.status != Kept;
      $promise.keep(Nil);
    };
    ($promise, $res.promise).map(-> $p { try { $p.keep(Nil); }; });
    await Promise.allof($promise, $res.promise);
  }

};
