#!/usr/bin/env perl -w
use strict;
use lib '..';
use Test::More;

my @errors;
eval { require Test::Pod; };
push @errors, "Test::Pod is required for testing POD"   if $@;
eval { require Pod::Simple; };
push @errors, "Pod::Simple is required for testing POD" if $@;

if ( @errors ) {
   plan skip_all => "Errors detected: @errors";
}
else {
   Test::Pod::all_pod_files_ok();
}
