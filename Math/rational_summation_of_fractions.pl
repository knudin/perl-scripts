#!/usr/bin/perl

# Author: Daniel "Trizen" Șuteu
# License: GPLv3
# Date: 23 June 2016
# Website: https://github.com/trizen

# Rationalized summation of fractions, based on the principle:
#
#  a     c     ad + bc
# --- + --- = ----------
#  b     d       bd

# Combining this method with memoization, results in a practical
# generalized algorithm for summation of arbitrary fractions.

# In addition, with this method, any infinite sum can be converted into a limit.

# Example:                ∞
#            f(n)        ---  1
#  lim    ----------  =  \   ----  = e
#  n->∞      _n_         /    n!
#            | | k!      ---
#            k=0         n=0
#
# where:                     _n_
#   f(n+1) = (n+1)! * f(n) + | | k!
#                            k=0
#   f(0)   = 1
#
#====================================================
#
# Generally:
#
#   x
#  ---
#  \    a(n)        f(x)
#   -  ------ =  -----------
#  /    b(n)       _x_
#  ---             | | b(k)
#  n=0             k=0
#
# where:                              _n_
#   f(n+1) = b(n+1) * f(n) * a(n+1) * | | b(k)
#                                     k=0
#   f(0)   = a(0)

use 5.010;
use strict;
use warnings;

use Memoize qw(memoize);
use Math::BigNum qw(:constant);

memoize('f');
memoize('b');
memoize('p');

my $start = 0;     # start iteration from this value
my $iter  = 90;    # number of iterations

sub a {
    2**$_[0];
}

sub b {
    $_[0]->fac;
}

sub f {
    my ($n) = @_;
    $n <= $start
      ? a($n)
      : b($n) * f($n - 1) + a($n) * p($n - 1);
}

sub p {
    my ($n) = @_;
    $n <= $start
      ? b($n)
      : b($n) * p($n - 1);
}

my $x = f($iter) / p($iter);
say $x->as_rat;
say "e^2 =~ ", $x->as_float(64);
