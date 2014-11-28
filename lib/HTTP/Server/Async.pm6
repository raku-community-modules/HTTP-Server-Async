use HTTP::Server::Async::Request;
use HTTP::Server::Async::Response;

class HTTP::Server::Async {
  has Str     $.host     = '127.0.0.1';
  has Int     $.port     = 8080;
  has Bool    $.buffered = True;
  has Int     $.timeout  = 30;

  has Promise $!promise;
  has Channel $!parser;
  has Channel $!responder;
  
  has @.responsestack;
  has %!connections;
  has @!middleware;
  has $!server;

  method middleware(Str $class) {
    require($class);
    @!middleware.push($class);
  }

  method listen {
    my $connid  = 0;
    $!promise   = Promise.new;
    $!server    = IO::Socket::Async.listen($.host, $.port) or 
                     die "Couldn't listen on $.host:$.port";
    $!parser    = Channel.new;
    $!responder = Channel.new;

    self!parse_worker;
    self!respond_worker;
    $!server.tap(-> $connection {
      my $id  = $connid++;
      my $tap = $connection.chars_supply.tap(-> $data {
        $!parser.send({ 
          id         => $connid, 
          connection => $connection, 
          data       => $data,
          tap        => $tap,
          now        => now,
        });
      });
    }, quit => {
      $!promise.vow.keep(True); 
    });

    $*SCHEDULER.cue({
      for %!connections.keys -> $c {
        if (now - %!connections{$c}<now>).Int > $.timeout {
          %!connections{$c}<connection>.close;          
        }
      }
    }, :every($.timeout < 1 ?? $.timeout !! 2));
  }

  method register(Callable $sub){
    @.responsestack.push($sub);
  }

  method block {
    await $!promise;
    $!parser.close;
    $!responder.close;
  };

  method !parse_worker {
    start {
      loop {
        my $p = $!parser.receive;
        try {
          if !defined %!connections{$p<id>} {
            %!connections{$p<id>} = { 
              data => '',
              now  => $p<now>,
              req  => HTTP::Server::Async::Request.new,
              res  => HTTP::Server::Async::Response.new(
                        :connection($p<connection>), :$.buffered),
              tap  => $p<tap>,
              connection => $p<connection>,
              processing => False,
            };
          }
          %!connections{$p<id>}<data> ~= $p<data>;
          my $rbool = %!connections{$p<id>}<req>.parse(%!connections{$p<id>}<data>); 
          for @!middleware -> $class {
            try {
              my $rval = ::($class).new(
                request    => %!connections{$p<id>}<req>,
                response   => %!connections{$p<id>}<res>,
                tap        => %!connections{$p<id>}<tap>,
                connection => %!connections{$p<id>}<connection>,
              );

              if $rval.status {
                %!connections{$p<id>}<tap>.close;
                next;
              }
              CATCH { .say; }
            };
          }
          $!responder.send($p<id>) if $rbool; 
          CATCH { .say; }
        };
      }
    }
  }

  method !respond_worker {
    start {
      loop {
        my $r = $!responder.receive;
        next if %!connections{$r}<processing>;
        %!connections{$r}<processing> = True;
        my $index = 0;
        my $s = sub (Bool $next? = True) {
          if !$next || $index >= @.responsestack.elems || %!connections{$r}<res>.promise.status == Kept {
            #delete %!connections<$r>
            %!connections{$r}<connection>.close;
            %!connections{$r}<tap>.close;
            %!connections.delete_key($r);
            return;
          }
          @.responsestack[$index++](%!connections{$r}<req>, %!connections{$r}<res>, $s);
        };
        $s();
        CATCH { .say; }
      }
    }
  }
}
