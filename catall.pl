#!/usr/bin/perl 

# This simple script gets a path, and cat them all simply to STDOUT 
use warnings;
use strict; 

die "usage: one argument needed; a path. The script will cat all files in that dir" unless ($ARGV[0]); 


my @ls = glob("$ARGV[0]/*"); 
foreach (@ls)
{
    open FILE, "<", $_; 
    print while (<FILE>); 
    close FILE; 
}
