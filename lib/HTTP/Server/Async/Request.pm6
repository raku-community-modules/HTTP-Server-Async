class HTTP::Server::Async::Request {
  has $.method   is rw;
  has $.uri      is rw;
  has $.version  is rw;
  has %.headers  is rw;
  has $.data     is rw;
  
  has $!headercomplete  = False;
  has $!sentheadcomp    = False;
  has $!requestcomplete = False;
  has $.promise         = Promise.new;

  method parse ($data) {
    try {
      my ($headerstr, $bodystr) = $data.split("\r\n\r\n", 2);
      my (%headers, @headera, @method);
      if !$!headercomplete {
        @headera = $headerstr.split("\r\n");
        return False if @headera.elems == 0;
        @method  = "{@headera.shift}".split(' ');
        
        for @headera {
          my ($k,$v) = "$_".split(':',2);
          %headers{$k.trim} = Any !~~ $v.WHAT ?? $v.trim !! ''; 
        }
        $.method  = @method.shift;
        $.version = @method.pop;
        $.uri     = @method.join(' ');
        $!headercomplete = True if $data.index("\r\n\r\n");
      }

      #detect end of req
      try { 
        if $bodystr ~~ Str && so %headers<Transfer-Encoding>:exists && %headers<Transfer-Encoding> eq 'chunked' {
          try {
            my $i   = 0;
            my $tr  = 0;
            $.data = '';
            while $i < $bodystr.chars && ($tr = :16($bodystr.substr($i, $bodystr.index("\r", $i) - $i))) != 0 {
              $i     += $bodystr.index("\r", $i) - $i + 2;
              $.data ~= $bodystr.substr($i, $tr);
              $i     += $tr + 2;
            }
            $!requestcomplete = True if $tr == 0;
          };
          $.promise.vow.keep(1);
          return False;

        } elsif $bodystr ~~ Str {
          $.data ~= $bodystr;
          $.promise.vow.keep(1);
          $!requestcomplete = True;
        }
      };

      if $!headercomplete && !so $!sentheadcomp {
        $!sentheadcomp = True;
        return True;
      }
      return False;

      CATCH { default { return False; } }
    };
  };
}
