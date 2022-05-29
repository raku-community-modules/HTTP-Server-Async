[![Actions Status](https://github.com/raku-community-modules/HTTP-Server-Async/actions/workflows/test.yml/badge.svg)](https://github.com/raku-community-modules/HTTP-Server-Async/actions)

NAME
====

HTTP::Server::Async - Asynchronous Base HTTP Server

SYNOPSIS
========

```raku
use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

$s.handler:  -> $request, $response {
    $response.headers<Content-Type> = 'text/plain';
    $response.status = 200;
    $response.write("Hello ");
    # keeps a promise in the response and ends the server handler processing
    $response.close("world!");
}

$s.listen(True);
```

DESCRIPTION
===========

HTTP::Server::Async provides an implementation of an HTTP server, based on the roles provided by `HTTP::Roles`.

It currently handles:

  * Parsing Headers

  * Chunked Transfer

  * Hooks for middleware or route handling

  * Simple response handling

It does **not** handle:

  * ~~Route handling~~ (See [`HTTP::Server::Router`](https://github.com/tony-o/perl6-http-server-router))

  * ~~File transfers~~

CLASSES
=======

HTTP::Server::Async
-------------------

### new

Takes these named arguments to return an instantiated object:

  * :port - port to listen on

  * :host - IP number to listen on

  * :buffered - whether responses should be buffered or not (Bool)

### handler

Any `Callable` passed to this method is registered to be called on every incoming request in the order in which they were registered.

Any registered `Callable` should return `True` to continue processing. A `False` value will discontinue processing of the request. Alternatively a `Promise` can be returned: if the `Promise` is broken then the server will discontinue, if the promise is kept then processing will continue. 

The `Callable` will receive two parameters from the server, an `HTTP::Server::Async::Request` and a `HTTP::Server::Async::Response` object. More about the `Response` and `Request` object below.

Note that the server will wait for the request body to be complete before calling `Callable` registered with `handler`.

### middleware

The same as the `handler` except will **NOT** wait for a complete request body. The middleware can hijack the connection by explicitly returning `False` and continuing processing using `$request.connection` to gain control of the socket.

### listen

Starts the server and does **not** block, unless called with a `True` value.

HTTP::Server::Async::Request
----------------------------

This handles the parsing of an incoming request.

### Attributes

#### method

GET/PUT/POST/etc.

#### headers

hash with Key/value pair containing the header values.

#### uri

Requested resource.

#### version

HTTP/1.X (or whatever was in the request).

#### data

String containing the data included with the request.

HTTP::Server::Async::Response
-----------------------------

Response object, handles writing and closing the socket.

### Attributes

#### buffered

Whether or not the response object should buffer the response and write on close, or write directly to the socket.

#### status

Set the status of the response, uses HTTP status codes. See [RFC2616](http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html) for more information. Defaults to 200.

#### headers

Hash with response headers to be sent, accessed directly. Modifying these after writing to the socket will have no effect on the response unless the `buffered` is set to True.

### Methods

#### write

Write data to the socket, will call the appropriate method for the socket (`$connection.write` for `Str`s, anything else is `$connection.send`)

#### close

Close takes optional parameter of data to send out. Will call `write` if a parameter is provided. Closes the socket, writes headers if the response is buffered, etc.

CREDITS
=======

Thanks to ugexe, btyler, jnthn, and timotimo for helping figure out bugs, answer a bunch of questions, etc.

AUTHOR
======

Tony O'Dell

COPYRIGHT AND LICENSE
=====================

Copyright 2014 - 2019 Tony O'Dell

Copyright 2020 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

