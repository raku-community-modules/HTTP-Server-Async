use HTTP::Response;

class HTTP::Server::Async::Response does HTTP::Response {
  has @!buffer;
  has Bool $!buffered = True;
  has Bool $!senthead = False;

  method !sendheaders (Bool $lastcall? = False) {
    return if $!senthead || (! $lastcall && $!buffered);
    %.headers<Content-Type> = 'text/html'  unless %.headers<Content-Type>:exists;
    %.headers<Connection>   = 'keep-alive' unless %.headers<Connection>:exists;
    try {
      $!senthead = True;
      my @pairs = %.headers.keys.map({ 
        "$_: {$.headers{$_}}"
      });
      await $.connection.print("HTTP/1.1 $.status {%!statuscodes{$.status}}\r\n");
      await $.connection.print(@pairs.join("\r\n") ~ "\r\n\r\n");
    };
  }

  method unbuffer {
    return True unless $!buffered;
    return try {
      CATCH { default { return False; } }
      $!buffered = False;
      $.flush;
      return True;
    };
  }

  method rebuffer {
    return False if $!buffered || $!senthead;
    $!buffered = True;
  }

  method flush {
    self!sendheaders(True);
    for @!buffer -> $buff {
      await $.connection.write($buff);
    }
    @!buffer = Array.new;
  }

  method write($data) {
    try {
      self!sendheaders;
      my $d = $data.^can('encode') ?? $data.encode !! $data;
      return if $d.elems == 0;
      @!buffer.push($d) if $!buffered;
      await $.connection.write($d) unless $!buffered;
    };
  }

  method close($data?, :$force? = False) {
    try {
      if Any !~~ $data { 
        $.write($data);
      }
    };
#set content-length
    my $cl = 0;
    for @!buffer -> $buf {
      $cl += $buf.elems;
    }
    %.headers<Content-Length> = $cl;
    $.flush;
    try {
      $.connection.close unless (%.headers<Connection>.index('keep-alive') // -1) > -1 || $force;
    };
  }
};
