use HTTP::Request;
use HTTP::Server::Async::Response;

class HTTP::Server::Async::Request does HTTP::Request {
  has HTTP::Server::Async::Response $.response;

  has Bool $.complete is rw = False;
  has $.connection is rw;

  
}
