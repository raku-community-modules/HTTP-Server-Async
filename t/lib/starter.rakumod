use HTTP::Server::Async;
use Test;

my constant $host = '127.0.0.1';
my constant $port = (6000..8000).pick;
my $s;

sub host is export { $host }
sub port is export { $port }
sub srv(|opts) is export {
    HTTP::Server::Async.new(:ip($host), :$port, |opts) or die 'dead'
}
sub req is export {
    my $c;
    my $s = False;
    while !$s {
        try {
            $c = IO::Socket::INET.new(:$host, :$port) or die 'couldn\'t connect';
            $s = True;
        }
    }
    $c
}

# vim: expandtab shiftwidth=4
