use HTTP::Server::Async;

my $s := HTTP::Server::Async.new;

$s.handler(sub ($req, $res) {
    $res.write('world');
    $res.close();
});

$s.listen(True);

# vim: expandtab shiftwidth=4
