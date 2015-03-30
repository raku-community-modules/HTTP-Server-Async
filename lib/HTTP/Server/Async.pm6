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
  has Channel $!timeoutc;
  
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
    $!timeoutc  = Channel.new;

    self!parse_worker;
    self!respond_worker;
    self!timeout_worker;
    $!server.tap(-> $connection {
      my $id      = $connid++;
      my $tap     = $connection.chars_supply.tap(-> $data {
        $!parser.send({ 
          id         => $id, 
          connection => $connection, 
          data       => $data,
          tap        => $tap,
          now        => now,
        });
      });
      $*SCHEDULER.cue({
        $!timeoutc.send($connection // Nil);
      }, :in($.timeout));
    }, quit => {
      $!promise.vow.keep(True); 
    });
  }

  method register(Callable $sub){
    @.responsestack.push($sub);
  }

  method block {
    await $!promise;
    $!parser.close;
    $!responder.close;
  };

  method !timeout_worker {
    start {
      loop {
        my $conn = $!timeoutc.receive;
        try {
          $conn.close;
        }
      }
    };
  }

  method !parse_worker {
    start {
      loop {
        my $p = $!parser.receive;
        try {
          if !(%!connections{$p<id>}:exists) {
            my $req = HTTP::Server::Async::Request.new;
            %!connections{$p<id>} = { 
              data       => '',
              now        => $p<now>,
              req        => $req,
              res        => HTTP::Server::Async::Response.new(
                              :connection($p<connection>), 
                              :$.buffered,
                              :request($req),
                            ),
              tap        => $p<tap>,
              connection => $p<connection>,
              processing => False,
            };
          } elsif %!connections{$p<id>}<req>.promise.status ~~ Kept {
            %!connections{$p<id>}<data> = '';
            %!connections{$p<id>}<req>  = HTTP::Server::Async::Request.new;
            %!connections{$p<id>}<res>  = HTTP::Server::Async::Response.new(
                                            :connection($p<connection>), 
                                            :$.buffered,
                                            :request(%!connections{$p<id>}<req>),
                                          );
            %!connections{$p<id>}<processing> = False;
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
        my $req = %!connections{$r}<req>;
        my $res = %!connections{$r}<res>;
        my $index = 0;
        my $s = sub (Bool $next? = True) {
          if !$next || $index >= @.responsestack.elems || $res.promise.status ~~ Kept {
            #delete %!connections<$r>
            if !($res.headers<Connection> // '').match(/ 'keep-alive' /) {
              %!connections{$r}<connection>.close; 
              %!connections{$r}<tap>.close;
              %!connections.delete_key($r);
            }
            return;
          }
          @.responsestack[$index++]($req, $res, $s);
        };
        $s();
        CATCH { .say; }
      }
    }
  }
}
