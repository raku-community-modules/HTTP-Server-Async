unit module HTTP::Server::Async::Plugins::Middleware::Hijack;

sub hijack($request, $response) is export {
  $response.close('Hijacked.');
  False;
}
