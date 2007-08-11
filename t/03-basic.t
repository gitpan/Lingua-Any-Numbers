#!/usr/bin/env perl -w
use strict;
use Lingua::Any::Numbers qw(:std);
use Test::More tests => 3;

ok( available() );
ok( to_string(  45 ) );
ok( to_ordinal( 45 ) );
