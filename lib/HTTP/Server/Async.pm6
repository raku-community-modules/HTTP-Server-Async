use HTTP::Server:auth<github:tony-o>;
use HTTP::Server::Async::Request;
use HTTP::Server::Async::Response;

class HTTP::Server::Async does HTTP::Server {
  has Int      $.port          = 1666;
  has Str      $.ip            = '0.0.0.0';
  has Channel  $.requests     .= new;
  has Int      $.timeout is rw = 8;

  has Supply $.socket  is rw;

  has @.handlers;
  has @.afters;
  has @.middlewares;
  has @!connects;

  method handler(Callable $sub) {
    @.handlers.push($sub);
  }

  method after(Callable $sub) {
    @.afters.push($sub);
  }

  method middleware(Callable $sub) {
    @.middlewares.push($sub);
  }

  method !timeout {
    my Lock $l .=new;
    start {
      loop {
        sleep 1;
        CATCH { default { .say; } }
        $l.protect({
          @!connects = @!connects.grep({ !$_<closedorclosing>.defined });
        });
        for @!connects.grep({ now - $_<last-active> >= $.timeout }) {
          CATCH { default { .say; } }
          try {
            $_<closedorclosing> = True;
            $_<connection>.write(Blob.new); #https://irclog.perlgeek.de/perl6/2017-02-09#i_14073278
            $_<connection>.close; 
          };
        }
      };
    };
  }

  method !remove-timeout($conn) {
    for @!connects.grep({ $_<connection> eqv $conn }) {
      try {
        $_<closedorclosing> = True;
        $_<connection>.write(Blob.new);
        $_<connection>.close;
      };
    }
  }

  method !reset-time($conn) {
    for @!connects.grep({ $_<connection> eqv $conn }) {
      $_<last-active> = now;
    }
  }

  method listen(Bool $block? = False) {
    my Promise $prom .=new;
    my Buf     $rn   .=new("\r\n\r\n".encode);

    self!responder;
    self!timeout;

    $.socket = IO::Socket::Async.listen($.ip, $.port) or die "Failed to listen on $.ip:$.port";
    $.socket.tap(-> $conn {
      my Buf $data .=new;
      my Int $index = 0;
      my     $req   = Nil;
      @!connects.push({
        connection  => $conn,
        last-active => now,
      });
      
      $conn.Supply(:bin).tap(-> $bytes {
        $data ~= $bytes;
        self!reset-time($conn);
        while $index++ < $data.elems - 3 {
          $index--, last if $data[$index]   == $rn[0] &&
                            $data[$index+1] == $rn[1] &&
                            $data[$index+2] == $rn[2] &&
                            $data[$index+3] == $rn[3];
        }

        self!parse($data, $index, $req, $conn) if $index != $data.elems - 3 || $req.^can('complete');
        CATCH { default { .say; } }
      });
      CATCH { default { .say; } }
    }, quit => {
      $prom.keep(True);
    });

    await $prom if $block;
    return $prom;
  }

  method !responder {
    start {
      loop {
        CATCH { default { .say; } }
        my $req = $.requests.receive;
        my $res = $req.response;
        my $prm;
        for @.handlers -> $h {
          try {
            CATCH {
              default {
                .say;
              }
            }
            my $r = $h.($req, $res);
            $prm  = self!rc($r);
            last if $prm;
          };
        }

        for @.afters -> $a {
          try {
            CATCH {
              default {
                .say;
              }
            }
            $a.($req, $res);
          }
        }
        
        $res.close(:force(True)) and self!remove-timeout($res.connection) 
          if $prm || 
             ($req.header('Connection')[0]<Connection> // '').lc ne 'keep-alive';
      };
    };
  }

  method !parse($data is rw, $index is rw, $req is rw, $connection) {
    $req = Nil if $req !~~ Nil && $req.^can('complete') && $req.complete;
    if $req ~~ Nil || !( $req.^can('headers') && $req.headers.keys.elems ) {
      my @lines       = Buf.new($data[0..$index]).decode.lines;
      return unless @lines[0].match(/^(.+?)\s(.+)\s(HTTP\/.+)$/);
      my ($m, $u, $v) = (@lines.shift.match(/^(.+?)\s(.+)\s(HTTP\/.+)$/) // []).list.map({ .Str });
      my %h;
      my $last-key = '';
      for @lines -> $line {
        if $line ~~ /^\s/ && $last-key {
          %h{$last-key} ~= $line.trim;
        } else { 
          my ($k,$v) = $line.split(':', 2).map({.trim});
          $last-key = $k;
          if %h{$k}:exists {
            %h{$k} = [%h{$k},] if %h{$k} !~~ Array;
            %h{$k}.push($v);
          } else {
            %h{$k} = $v;
          }
        }
      }

      $req    = HTTP::Server::Async::Request.new(
                  :method($m), 
                  :uri($u), 
                  :version($v), 
                  :headers(%h), 
                  :connection($connection),
                  :response(HTTP::Server::Async::Response.new(:$connection)));
      $req.data .=new;
      $index += 4;
      $data   = Buf.new($data[$index+1..$data.elems-1]);
      $index  = 0;
      for @.middlewares -> $m {
        try {
          CATCH {
            default {
              .say;
            }
          }
          my $r = $m.($req, $req.response);
          return if self!rc($r);
        };
      }
    }
    CATCH { default { .say; } }
    if $req !~~ Nil && $req.header('Transfer-Encoding').lc.index('chunked') !~~ Nil {
      my ($i, $bytes) = 0,;
      my Buf $rn .=new("\r\n".encode);
      while $i < $data.elems {
        $i++ while $data[$i]   != $rn[0] &&
                   $data[$i+1] != $rn[1] &&
                   $i + 1 < $data.elems;
        last if $i + 1 >= $data.elems;

        $bytes = :16($data.subbuf(0,$i).decode);
        last if $data.elems < $i + $bytes;
        if $bytes == 0 { 
          try $data .=subbuf(3);
          $req.complete = True;
          last; 
        } 
        $i+=2;
        $req.data ~= $data.subbuf($i, $i+$bytes-3);
        try $data .=subbuf($i+$bytes+2);
        $i = 0;
      }
    } else {
      my $req-len = try { $req.header('Content-Length')[0].value } // ($data.elems - $index);
      if $data.elems - $req-len >= 0 {
        $req.data     = Buf.new($data[0..$req-len].Slip); 
        $req.complete = True;
        $data = Buf.new($data[$req-len..$data.elems].Slip);
      }
    }
    $.requests.send($req) 
      if $req.^can('complete') && $req.complete;
  }

  method !rc($r) {
    if $r ~~ Promise {
      try await $r;
      return True unless $r.status ~~ Kept;
    } else {
      return True unless $r;
    }
    return False;
  }
};

