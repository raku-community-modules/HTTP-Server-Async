class HTTP::Server::Async::Plugins::Middleware::Inject {
  has Bool $.status is rw;

  submethod BUILD(:$request, :$response, :$tap, :$connection) {
    $response.headers<XYZ> = 'ABC';
    $!status = False;
  }
};
