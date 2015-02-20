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
    $!server    = IO::Socket::INET.new(:localhost($.host), :localport($.port), :listen) or 
                     die "Couldn't listen on $.host:$.port";
    $!parser    = Channel.new;
    $!responder = Channel.new;
    $!timeoutc  = Channel.new;

    self!parse_worker;
    self!respond_worker;
    self!timeout_worker;
    start {
      while my $connection = $!server.accept {
        my $id   = $connid++;
        say "$connid connected";
        my $data = $connection.recv;
        "$connection\n$data\n------------".say;
        $!parser.send({ 
          id         => $connid, 
          connection => $connection, 
          data       => $data,
          now        => now,
        });
        $*SCHEDULER.cue({
          $!timeoutc.send($connection // Nil);
        }, :in($.timeout));
      }
      $!promise.vow.keep(True); 
    };
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
        "$p<id> parsing..".say;
        try {
          if ! %!connections.exists_key($p<id>) {
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
                connection => %!connections{$p<id>}<connection>,
              );

              if $rval.status {
                next;
              }
              CATCH { .say; }
            };
          }
          $!responder.send($p<id>) if $rbool; 
          CATCH { .say; }
        };
        CATCH { default { .say; .resume; } }
      }
    }
  }

  method !respond_worker {
    start {
      loop {
        my $r = $!responder.receive;
        next if %!connections{$r}<processing>;
        "$r responder".say;
        %!connections{$r}<processing> = True;
        my $req = %!connections{$r}<req>;
        my $res = %!connections{$r}<res>;
        my $index = 0;
        my $s = sub (Bool $next? = True) {
          "$r s'ing".say;
          if !$next || $index >= @.responsestack.elems || $res.promise.status ~~ Kept {
            "$r check close".say;
            if !($res.headers<Connection> // '').match(/ 'keep-alive' /) {
              %!connections{$r}<connection>.close; 
              "$r close".say;
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
