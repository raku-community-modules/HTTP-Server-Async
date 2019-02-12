# HTTP::Server::Async

[![Build Status](https://travis-ci.org/perl6-community-modules/perl6-http-server-async.svg?branch=master)](https://travis-ci.org/perl6-community-modules/perl6-http-server-async)

Asynchronous HTTP server.  

## Currently handles:
* Parsing Headers
* Chunked Transfer
* Hooks for middleware or route handling
* Simple response handling

## Doesn't handle
* ~~Route handling~~ (See [`HTTP::Server::Router`](https://github.com/tony-o/perl6-http-server-router))
* ~~File transfers~~

## Example
```perl6
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

$s.handler(sub ($request, $response) {
  $response.headers<Content-Type> = 'text/plain';
  $response.status = 200;
  $response.write("Hello ");
  $response.close("world!"); #keeps a promise in the response and ends the server handler processing
});

$s.listen(True);
```

## Methods

### .new
`:port` - port to listen on
`:host` - ip to listen on
`:buffered` - Boolean value for whether responses should be buffered or not

### .handler ( Callable($request, $response) )
Any Callable passed to this method is called in the order it was registered on every 
incoming request.  Any method/sub registered with the server should return `True` to 
continue processing.  A `False` value will discontinue processing. Alternatively a 
promise can be returned, if the promise is broken then the server will discontinue,
if the promise is kept then processing will continue. 

Callable will receive two parameters from the server, a `HTTP::Server::Async::Request` and a `HTTP::Server::Async::Response`.  More about the `Response` and `Request` object below.

Note that the server will wait for the request body to be complete before calling `handler` subs.


### .middleware ( Callable($request, $response) )
The same as the `handler` except will *NOT* wait for a complete request body. The
middleware can hijack the connection by explicitly returning `False` and continuing
processing using `$request.connection` to gain control of the socket.

### .listen ( Bool $block? = False ) 
Starts the server and does *not* block 

## HTTP::Server::Async::Request

This handles the parsing of the incoming request

### Attributes

#### $.method 
GET/PUT/POST/etc

#### %.headers
Key/value pair containing the header values

#### $.uri
Requested resource

#### $.version
`HTTP/1.1` or `HTTP/1.0` (or whatever was in the request)

#### $.data
String containing the data included with the request

## HTTP::Server::Async::Response

Response object, handles writing and closing the socket

### Attributes

#### $.buffered (Bool) = True
Whether or not the response object should buffer the response and write on close, or write directly to the socket

#### $.status (Int)
Set the status of the response, uses HTTP status codes.  See [here](http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html) for more info

#### %.headers
Response headers to be sent, accessed directly.  Modifying these after writing to the socket will have no effect on the response unless the `$.buffered` is set to True

### Methods

#### write
Write data to the socket, will call the appropriate method for the socket (Str = $connection.write, anything else is $connection.send)

#### close
Close takes optional parameter of data to send out.  Will call `write` if a parameter is provided.  Closes the socket, writes headers if the response is buffered, etc 

## Closing Credits

thanks to ugexe, btyler, jnthn, and timotimo for helping figure out bugs, answer a bunch of questions, etc


