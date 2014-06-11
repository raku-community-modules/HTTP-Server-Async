#!/usr/bin/env perl6

use HTTP::Request;

class HTTP::Server::Async {
  has $.host       = '127.0.0.1';
  has $.port       = 8080;
  has $.debug      = 1;
  has $.buffermode = 0;

  has @.responsestack;

  method listen() {
    my $num = 0;
    IO::Socket::Async.listen($.host,$.port,).tap(-> $connection {
      my $data    = '';
      my $request = HTTP::Request.new;
      $connection.chars_supply.tap({ 
        $data ~= $_;
        self!respond($connection, $request) if self!parse($request, $data) == 1;
      });
    });
  }

  method register(Callable $sub) {
    @.responsestack.push($sub);
  }

  method !respond($c, $request) {
    for @.responsestack -> $sub {
      try {
        $c.close if so $sub.($c, $request);
      };
    }
    try {
      $c.close;
    };
  }

  method !parse($r is rw, $d) {
    my ($headerstr, $bodystr) = $d.split("\r\n\r\n", 2);
    my %headers;
    my $request; 
    my @headers = $headerstr.split("\r\n");
    return 0 if @headers.elems == 0;
    my @method  = "{@headers.shift}".split(' ');
    
    for @headers {
      my ($k,$v) = "$_".split(':',2);
      %headers{$k.trim} = $v.trim; 
    }
    $r.method  = @method.shift;
    $r.version = @method.pop;
    $r.uri     = @method.join(' ');

    #detect end of req
    if so %headers<Transfer-Encoding>:exists && %headers<Transfer-Encoding> eq 'chunked' {
      my $i   = 0;
      my $tr  = 0;
      $r.data = '';
      while $i < $bodystr.chars && ($tr = :16($bodystr.substr($i, $bodystr.index("\r", $i) - $i))) != 0 {
        $i += $bodystr.index("\r", $i) - $i + 2;
        $r.data ~= $bodystr.substr($i, $tr);
        $i      += $tr + 2;
      }
      return 1 if $tr == 0; 
      return 0;

    } else {

      $r.data ~= $bodystr;
      return 1;
    }

    return 1; #complete request
  }

};
