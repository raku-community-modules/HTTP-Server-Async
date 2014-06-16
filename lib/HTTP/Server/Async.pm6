#!/usr/bin/env perl6

use HTTP::Server::Async::Request;
use HTTP::Server::Async::Response;

class HTTP::Server::Async {
  has $.host          = '127.0.0.1';
  has $.port          = 8080;
  has $.debug         = 1;
  has Bool $.buffered = True;

  has @.responsestack;

  method listen() {
    my $num = 0;
    my $con = IO::Socket::Async.listen($.host,$.port,) or die "Couldn't listen on port: $.port";
    $con.tap(-> $connection {
      my $data     = '';
      my $request  = HTTP::Server::Async::Request.new;
      my $response = HTTP::Server::Async::Response.new(:$connection, :$.buffered); 
      $connection.chars_supply.tap({ 
        $data ~= $_;
        self!respond($request, $response) if $request.parse($data):so;
      });
    });
  }

  method register(Callable $sub) {
    @.responsestack.push($sub);
  }

  method !respond($c, $request) {
    for @.responsestack -> $sub {
      try {
        $c.close, last if so $sub.($c, $request);
      };
    }
    try {
      $c.close;
    };
  }

};
