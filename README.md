#HTTP::Server::Async

Asynchronous HTTP server.  

##Currently handles:
* Parsing Headers
* Chunked Transfer
* Hooks for middleware or route handling
* Simple response handling

##Doesn't handle
* Route handling
* File transfers

##Example
```perl6
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

$s.register(sub ($request, $response, $next) {
  $response.headers<Content-Type> = 'text/plain';
  $response.status = 200;
  $response.write("Hello ");
  $response.close("world!");
});

$s.listen;
```

##Methods

###.new
`:port` - port to listen on
`:host` - ip to listen on
`:buffered` - Boolean value for whether responses should be buffered or not

###.register ( Callable )
Any Callable passed to this method is called in the order it was registered on every incoming request.  Any method/sub registered with the server should return `True` if the server should discontinue processing the request and return `False` if the message was not completely handled.

Callable will receive three parameters from the server, a `HTTP::Server::Async::Request` and a `HTTP::Server::Async::Response` and a `Callable`.  More about the `Response` and `Request` object below.

If the `Callable` parameter is not called by the `sub` and the response is closed then the next callable is not called (and that request is then completed, it is not left waiting for `Callable`).   

Note that the server will *NOT* wait for the request body to be complete before calling registered subs.

###.listen 
Starts the server and does *not* block 

###.block
Will block the main loop until the server stops 

##HTTP::Server::Async::Request

This handles the parsing of the incoming request

###Attributes

####$.method 
GET/PUT/POST/etc

####%.headers
Key/value pair containing the header values

####$.uri
Requested resource

####$.version
`HTTP/1.1` or `HTTP/1.0` (or whatever was in the request)

####$.data
String containing the data included with the request

##HTTP::Server::Async::Response

Response object, handles writing and closing the socket

###Attributes

####$.buffered (Bool) = True
Whether or not the response object should buffer the response and write on close, or write directly to the socket

####$.status (Int)
Set the status of the response, uses HTTP status codes.  See [here](http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html) for more info

####%.headers
Response headers to be sent, accessed directly.  Modifying these after writing to the socket will have no effect on the response unless the `$.buffered` is set to True

###Methods

####write
Write data to the sucket, will call the appropriate method for the socket (Str = $connection.write, anything else is $connection.send)

####close
Close takes optional parameter of data to send out.  Will call `write` if a parameter is provided.  Closes the socket, writes headers if the response is buffered, etc 


