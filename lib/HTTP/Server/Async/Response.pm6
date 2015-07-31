use HTTP::Server::Async::Request;
class HTTP::Server::Async::Response {
  has Int  $.status is rw = 200;
  has Bool $.buffered is rw = True;
  has Bool $!str      = True;
  has Bool $!senthead = False;
  has HTTP::Server::Async::Request $.request;
  has $.promise = Promise.new;
  has %.headers is rw = Content-Type => 'text/html', Connection => 'keep-alive';
  has @!buffer;
  has $.connection;

  method !sendheaders (Bool $lastcall? = False) {
    return if $!senthead || (!$lastcall && $.buffered);
    if ($.request.headers<Connection> // '').match(/ ^ 'keep-alive' /) {
      %.headers<Connection> = 'keep-alive';
    }
    try {
      $!senthead = True;
      my @pairs = map { "$_: {%.headers{$_}}" }, %.headers.keys;
      @pairs.push("Content-Length: {@!buffer.join('').chars}") if $.buffered;
      my $promise = $.connection.print("HTTP/1.1 $!status {%!statuscodes{$!status}}\r\n");
      await $promise;
      $promise = $.connection.print(@pairs.join("\r\n") ~ "\r\n\r\n");
      await $promise;
      CATCH { default { .resume; } }
    };
  }

  method unbuffer {
    return unless $.buffered;
    try {
    $.buffered = False;
    $.flush;
    CATCH { default { .say; } }
    };
  }

  method rebuffer {
    return if $.buffered;
    $.buffered = True;
  }

  method flush {
    self!sendheaders(True);
    for @!buffer -> $buff {
      await $.connection.write($buff) if $buff.WHAT !~~ Str;
      await $.connection.print($buff) if $buff.WHAT ~~ Str;
    }
  }

  method write($data) {
    return if $data !~~ Str;
    try {
      self!sendheaders;   
    };
    try { 
      @!buffer.push($data) if $.buffered;
      await $.connection.write($data) if $data.WHAT !~~ Str && !$.buffered;
      await $.connection.print($data)  if $data.WHAT  ~~ Str && !$.buffered;
      $!str = False if $data.WHAT !~~ Str;
    };
  }

  method close($data?, :$force? = False) {
    try {
      if Any !~~ $data.WHAT {
        $.write($data);
      }
    };
    try {
      self!sendheaders(True) if $.buffered;
    };
    try {
      if $.buffered {
        await $.connection.print(@!buffer.join(''));
      }
    };
    try {
      if !%.headers<Connection>.match(/ 'keep-alive' /) || $force {
        $.connection.close;
      }
    };
    try {
      $.promise.keep(True);
    };
    return;
  }


  has %!statuscodes = (
    100 => 'Continue',
    101 => 'Switching Protocols',
    102 => 'Processing',
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',
    203 => 'Non-Authoritative Information',
    204 => 'No Content',
    205 => 'Reset Content',
    206 => 'Partial Content',
    207 => 'Multi-Status',
    208 => 'Already Reported',
    226 => 'IM Used',
    300 => 'Multiple Choices',
    301 => 'Moved Permanently',
    302 => 'Found',
    303 => 'See Other',
    304 => 'Not Modified',
    305 => 'Use Proxy',
    306 => '(Unused)',
    307 => 'Temporary Redirect',
    308 => 'Permanent Redirect',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    402 => 'Payment Required',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    407 => 'Proxy Authentication Required',
    408 => 'Request Timeout',
    409 => 'Conflict',
    410 => 'Gone',
    411 => 'Length Required',
    412 => 'Precondition Failed',
    413 => 'Payload Too Large',
    414 => 'URI Too Long',
    415 => 'Unsupported Media Type',
    416 => 'Requested Range Not Satisfiable',
    417 => 'Expectation Failed',
    422 => 'Unprocessable Entity',
    423 => 'Locked',
    424 => 'Failed Dependency',
    426 => 'Upgrade Required',
    428 => 'Precondition Required',
    429 => 'Too Many Requests',
    431 => 'Request Header Fields Too Large',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported',
    506 => 'Variant Also Negotiates (Experimental)',
    507 => 'Insufficient Storage',
    508 => 'Loop Detected',
    510 => 'Not Extended',
    511 => 'Network Authentication Required',
  )

}
