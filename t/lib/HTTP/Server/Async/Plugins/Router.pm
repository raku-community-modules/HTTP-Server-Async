
class HTTP::Server::Async::Plugins::Router {
  method new($req, $res, $s) {
    say "HERE";    
    $s(False);
  }
}
