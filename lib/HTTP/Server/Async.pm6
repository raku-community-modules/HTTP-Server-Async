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
    my $num = 0;
    $!prom  = Promise.new;
    $!conn  = IO::Socket::Async.listen($.host,$.port,) or die "Couldn't listen on port: $.port";
    $!conn.tap(-> $connection {
      my $data     = '';
      my $request  = HTTP::Server::Async::Request.new;
      my $response = HTTP::Server::Async::Response.new(:$connection, :$.buffered); 
      $connection.chars_supply.tap({ 
        $data ~= $_;
        self!respond($request, $response) if $request.parse($data):so;
      });
    }, quit => {
      $!prom.keep(1);
    });
  }

  method block {
    await $!prom;
  }

  method register(Callable $sub) {
    @.responsestack.push(sub ($a, $b, $c) { 
      my $promise = Promise.new; 
      start { 
        try { $sub.($a,$b,$c); }; 
        $promise.keep(1);  
      }; 
      return $promise; 
    });
  }

  method !respond($req, $res) {
    my $*promise;
    my $n = sub {
      try {
        $*promise.keep(True);
        CATCH { default { say $!; say $_; }; };
      };
    };
    my $psub;
    for @.responsestack -> $sub {
      try {
        $*promise = Promise.new;
        $psub = $sub.($req, $res, $n);
        await Promise.anyof($*promise, $res.promise);
        last if $res.promise.status == Kept;
      };
    }

    try {
      $res.close if $res.promise.status != Kept;
    };
    $*promise.keep(0) if $*promise.status == Planned;
    await Promise.allof($*promise, $res.promise, $psub);
  }

};
