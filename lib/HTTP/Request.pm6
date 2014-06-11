class HTTP::Request {
  has $.method  is rw;
  has $.uri     is rw;
  has $.version is rw;
  has %.headers is rw;
  has $.data    is rw;
}
