#!/usr/bin/env perl6

use HTTP::Server::Async::Request;
use HTTP::Server::Async::Response;
use Pluggable;

class HTTP::Server::Async does Pluggable {
  has $.host          = '127.0.0.1';
  has $.port          = 8080;
  has $.debug         = 1;
  has $.timeout       = 30;
  has Bool $.buffered = True;
  has $!thread_buffer = 3;
  has @!plugins;
  has $!prom;
  has $!conn;
  has @.responsestack;


  method getplugins($pattern?, :$force = False) {
    @!plugins = @($.plugins) if so $force;
    return grep { $pattern:defined ?? .match($pattern) !! not .match(/^\s*$/) }, @!plugins;
  }

  method listen() {
    my $num = 0;
    $!prom  = Promise.new;
    $!conn  = IO::Socket::Async.listen($.host,$.port,) or die "Couldn't listen on port: $.port";
    $.getplugins(:force(True));
    $!conn.tap(-> $connection {
      if $*SCHEDULER.max_threads > $*SCHEDULER.loads + $!thread_buffer {
        my $data     = '';
        my $request  = HTTP::Server::Async::Request.new;
        my $response = HTTP::Server::Async::Response.new(:$connection, :$.buffered); 
        my ($rbool, $cbool);
        my $tap      = $connection.chars_supply.tap({ 
          try {
            $data ~= $_;
            $rbool = $request.parse($data);
            return if !so $rbool;
            for $.getplugins(/ 'Plugins::Middleware' /, :force(so $.debug ?? True !! False)) -> $class {
              try {
                $cbool = ::($class).new(:$data, :$request, :$response, :$tap).status;
                if $cbool {
                  $tap.close;
                  $rbool = False;
                  last;
                }
              };
            }
            self!respond($request, $response) if so $rbool;
          };
        });
      } else {
        $connection.close;
      }
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
    my $timeout = Promise.in($.timeout);
    my $exhaust = Promise.new;
    my $index = 0;
    my $s = sub (Bool $next? = True) {
      if (!so $next || $index >= @.responsestack.elems || $res.promise.status == Kept) {
        $exhaust.keep(True);
        return;
      }
      @.responsestack[$index++]( $req, $res, $s );
    };
    start { $s(True); };
    await Promise.anyof($timeout, $exhaust);

    try {
      $res.promise.keep(True), $res.close if $res.promise.status != Kept;
    };
    ($timeout, $exhaust, $res.promise).map(-> $p { try { $p.keep(Nil); }; });
    await Promise.allof($timeout, $exhaust, $res.promise);
  }

};
