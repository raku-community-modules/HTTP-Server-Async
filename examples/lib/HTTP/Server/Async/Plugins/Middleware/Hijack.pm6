class HTTP::Server::Async::Plugins::Middleware::Hijack {
  has $.status is rw;

  submethod BUILD(:$connection, :$request, :$response, :$tap) {
    try {
      $response.close("DONE");
    };
    $!status = True;
  }
};
