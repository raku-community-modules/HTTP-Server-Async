use HTTP::Server::Async::Request;
use HTTP::Server::Async::Response;
use Pluggable;

class HTTP::Server::Async does Pluggable {
  has Str     $.host     = '127.0.0.1';
  has Int     $.port     = 8080;
  has Bool    $.buffered = True;

  has Promise $!promise;
  has Channel $!parser;
  has Channel $!responder;
  
  has @.responsestack;
  has %!connections;
  has @!plugins;
  has $!server;

  method !getplugins($pattern?, :$force = False) {
    @!plugins = @($.plugins) if $force;
    return @!plugins if defined $pattern;
    return grep { .match($pattern) }, @!plugins;
  }

  method listen {
    my $connid  = 0;
    $!promise   = Promise.new;
    $!server    = IO::Socket::Async.listen($.host, $.port) or 
                     die "Couldn't listen on $.host:$.port";
    $!server.live.say;
    $!parser    = Channel.new;
    $!responder = Channel.new;
    @!plugins   = @($.plugins);

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
        });
      });

    }, quit => {
      'done'.say;
      $!promise.vow.keep(True); 
    }, closing => {
      's'.say; 
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

  method !parse_worker {
    start {
      loop {
        my $p = $!parser.receive;
        try {
          if !defined %!connections<id> {
            %!connections{$p<id>} = { 
              data => '',
              req  => HTTP::Server::Async::Request.new,
              res  => HTTP::Server::Async::Response.new(
                        :connection($p<connection>), :$.buffered),
              tap  => $p<tap>,
              connection => $p<connection>,
              processing => False,
            };
          }
          %!connections{$p<id>}<data> ~= $p<data>;
          my $rbool = %!connections{$p<id>}<req>.parse($p<data>); 
          for self!getplugins(/ 'Plugins::Middleware' /) -> $class {
            try {
              $class.say;
              my $cbool = ::($class).new(
                request    => %!connections{$p<id>}<req>,
                response   => %!connections{$p<id>}<res>,
                tap        => %!connections{$p<id>}<tap>,
                connection => %!connections{$p<id>}<connection>,
              ).status;
              if $cbool {
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
