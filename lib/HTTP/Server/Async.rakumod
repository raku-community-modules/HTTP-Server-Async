use HTTP::Server::Role;
use HTTP::Server::Async::Request;
use HTTP::Server::Async::Response;

class HTTP::Server::Async does HTTP::Server::Role {
    has Int     $.port          = 1666;
    has Str     $.ip            = '0.0.0.0';
    has Channel $.requests      = Channel.new;
    has Int     $.timeout is rw = 8;
    has Supply  $.socket  is rw;

    has @.handlers;
    has @.afters;
    has @.middlewares;
    has @!connects;

    method handler(Callable:D $sub) {
        @.handlers.push($sub);
    }

    method after(Callable:D $sub) {
        @.afters.push($sub);
    }

    method middleware(Callable:D $sub) {
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

    my constant $default-rn = Buf.new("\r\n\r\n".encode);
    method listen(Bool $block? = False) {
        my Promise $prom = Promise.new;
        my Buf     $rn   = $default-rn;

        self!responder;
        self!timeout;

        $.socket = IO::Socket::Async.listen($.ip, $.port)
          or die "Failed to listen on $.ip:$.port";

        $.socket.tap: -> $conn {
            CATCH { default { .say } }
            my Buf $data  = Buf.new;
            my Int $index = 0;
            my     $req;

            @!connects.push: {
                connection  => $conn,
                last-active => now,
            }
            
            $conn.Supply(:bin).tap: -> $bytes {
                CATCH { default { .say } }
                $data ~= $bytes;
                self!reset-time($conn);
                while $index++ < $data.elems - 4 {
                    $index--, last if $data[$index]   == $rn[0]
                                   && $data[$index+1] == $rn[1]
                                   && $data[$index+2] == $rn[2]
                                   && $data[$index+3] == $rn[3];
                }

                self!parse($data, $index, $req, $conn) 
                  if $index != $data.elems - 3 || $req.^can('complete');
            }
        }, quit => {
            $prom.keep(True);
        }

        await $prom if $block;
        $prom
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
                        CATCH { default { .say } }
                        my $r = $h.($req, $res);
                        $prm  = self!rc($r);
                        last if $prm;
                    };
                }

                for @.afters -> $a {
                    try {
                        CATCH { default { .say } }
                        $a.($req, $res);
                    }
                }
                
                $res.close(:force(True)) and self!remove-timeout($res.connection) 
                  if $prm
                  || ($req.header('Connection')[0]<Connection> // '').lc ne 'keep-alive';
            }
        }
    }

    method !parse($data is rw, $index is rw, $req is rw, $connection) {
        $req = Nil if $req && $req.^can('complete') && $req.complete;

        if !$req || !($req.^can('headers') && $req.headers.keys.elems) {
            my @lines = Buf.new($data[0..$index]).decode.lines;
            return unless @lines[0].match(/^(.+?)\s(.+)\s(HTTP\/.+)$/);

            my ($method, $uri, $version) =
              (@lines.shift.match(/^(.+?)\s(.+)\s(HTTP\/.+)$/) // [])
                .list
                .map: *.Str;

            my %headers;
            my $last-key = '';
            for @lines -> $line {
                if $line ~~ /^\s/ && $last-key {
                    %headers{$last-key} ~= $line.trim;
                }
                else { 
                    my ($k,$v) = $line.split(':', 2).map({.trim});
                    $last-key = $k;
                    if %headers{$k}:exists {
                        %headers{$k} = [%headers{$k},] if %headers{$k} !~~ Array;
                        %headers{$k}.push($v);
                    }
                    else {
                        %headers{$k} = $v;
                    }
                }
            }

            my $response := HTTP::Server::Async::Response.new(:$connection);
            $req = HTTP::Server::Async::Request.new:
              :$method, :$uri, :$version, :%headers, :$connection, :$response;

            $req.data .= new;
            $index    += 4;
            $data      = Buf.new($data[$index+1..$data.elems-1]);
            $index     = 0;
            for @.middlewares -> $middleware {
                try {
                    CATCH { default { .say } }
                    my $r = $middleware.($req, $req.response);
                    return if self!rc($r);
                };
            }
        }
        if $req && $req.header('Transfer-Encoding').lc.index('chunked') !~~ Nil {
            my int $i;
            my int $bytes;
            my Buf $rn .=new("\r\n".encode);
            while $i < $data.elems {
                $i++ while $data[$i]   != $rn[0]
                        && $data[$i+1] != $rn[1]
                        && $i + 1 < $data.elems;
                last if $i + 1 >= $data.elems;

                $bytes = :16($data.subbuf(0,$i).decode);
                last if $data.elems < $i + $bytes;
                if $bytes == 0 { 
                    try $data .=subbuf(3);
                    $req.complete = True;
                    last; 
                } 
                $i += 2;
                $req.data ~= $data.subbuf($i, $i+$bytes-3);
                try $data .=subbuf($i+$bytes+2);
                $i = 0;
            }
        }
        else {
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
        }
        else {
            return True unless $r;
        }
        False
    }
}

=begin pod

=head1 NAME

HTTP::Server::Async - Asynchronous Base HTTP Server

=head1 SYNOPSIS

=begin code :lang<raku>

use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

$s.handler:  -> $request, $response {
    $response.headers<Content-Type> = 'text/plain';
    $response.status = 200;
    $response.write("Hello ");
    # keeps a promise in the response and ends the server handler processing
    $response.close("world!");
}

$s.listen(True);

=end code

=head1 DESCRIPTION

HTTP::Server::Async provides an implementation of an HTTP server, based on
the roles provided by C<HTTP::Roles>.

It currently handles:
=item Parsing Headers
=item Chunked Transfer
=item Hooks for middleware or route handling
=item Simple response handling

It does B<not> handle:
=item ~~Route handling~~ (See [`HTTP::Server::Router`](https://github.com/tony-o/perl6-http-server-router))
=item ~~File transfers~~

=head1 CLASSES

=head2 HTTP::Server::Async

=head3 new

Takes these named arguments to return an instantiated object:

=item :port - port to listen on
=item :host - IP number to listen on
=item :buffered - whether responses should be buffered or not (Bool)

=head3 handler

Any C<Callable> passed to this method is registered to be called on
every incoming request in the order in which they were registered.

Any registered C<Callable> should return C<True> to continue processing.
A C<False> value will discontinue processing of the request. Alternatively
a C<Promise> can be returned: if the C<Promise> is broken then the server
will discontinue, if the promise is kept then processing will continue. 

The C<Callable> will receive two parameters from the server, an
C<HTTP::Server::Async::Request> and a C<HTTP::Server::Async::Response>
object.  More about the C<Response> and C<Request> object below.

Note that the server will wait for the request body to be complete
before calling C<Callable> registered with C<handler>.

=head3 middleware

The same as the C<handler> except will B<NOT> wait for a complete request
body. The middleware can hijack the connection by explicitly returning
C<False> and continuing processing using C<$request.connection> to gain
control of the socket.

=head3 listen

Starts the server and does B<not> block, unless called with a C<True>
value.

=head2 HTTP::Server::Async::Request

This handles the parsing of an incoming request.

=head3 Attributes

=head4 method

GET/PUT/POST/etc.

=head4 headers

hash with Key/value pair containing the header values.

=head4 uri

Requested resource.

=head4 version

HTTP/1.X (or whatever was in the request).

=head4 data

String containing the data included with the request.

=head2 HTTP::Server::Async::Response

Response object, handles writing and closing the socket.

=head3 Attributes

=head4 buffered

Whether or not the response object should buffer the response and write
on close, or write directly to the socket.

=head4 status

Set the status of the response, uses HTTP status codes.  See
L<RFC2616|http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html> for
more information.  Defaults to 200.

=head4 headers

Hash with response headers to be sent, accessed directly.  Modifying
these after writing to the socket will have no effect on the response
unless the C<buffered> is set to True.

=head3 Methods

=head4 write

Write data to the socket, will call the appropriate method for the
socket (C<$connection.write> for C<Str>s, anything else is
C<$connection.send>)

=head4 close

Close takes optional parameter of data to send out.  Will call C<write>
if a parameter is provided.  Closes the socket, writes headers if the
response is buffered, etc.

=head1 CREDITS

Thanks to ugexe, btyler, jnthn, and timotimo for helping figure out bugs,
answer a bunch of questions, etc.

=head1 AUTHOR

Tony O'Dell

=head1 COPYRIGHT AND LICENSE

Copyright 2014 - 2019 Tony O'Dell

Copyright 2020 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
