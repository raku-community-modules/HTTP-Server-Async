class HTTP::Server::Async::Request {
  has $.method  is rw;
  has $.uri     is rw;
  has $.version is rw;
  has %.headers is rw;
  has $.data    is rw;

  method parse ($data) {
    my ($headerstr, $bodystr) = $data.split("\r\n\r\n", 2);
    my %headers; 
    my @headera = $headerstr.split("\r\n");
    return False if @headera.elems == 0;
    my @method  = "{@headera.shift}".split(' ');
    
    for @headera {
      my ($k,$v) = "$_".split(':',2);
      %headers{$k.trim} = $v.trim; 
    }
    $.method  = @method.shift;
    $.version = @method.pop;
    $.uri     = @method.join(' ');

    #detect end of req
    if so %headers<Transfer-Encoding>:exists && %headers<Transfer-Encoding> eq 'chunked' {
      try {
        my $i   = 0;
        my $tr  = 0;
        $.data = '';
        while $i < $bodystr.chars && ($tr = :16($bodystr.substr($i, $bodystr.index("\r", $i) - $i))) != 0 {
          $i     += $bodystr.index("\r", $i) - $i + 2;
          $.data ~= $bodystr.substr($i, $tr);
          $i     += $tr + 2;
        }
        return True if $tr == 0; 
      };
      return False;

    } else {
      $.data ~= $bodystr;
      return True;
    }

    return True; #complete request
    
  };
}
