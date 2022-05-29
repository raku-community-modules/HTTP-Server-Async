class HTTP::Server::Async::Plugins::Middleware::Inject {
    method bind($app) {
        $app.middleware(sub ($req, $res) {
            $response.headers<XYZ> = 'ABC';
            $!status = False;
        }
        True
    }
}

# vim: expandtab shiftwidth=4
