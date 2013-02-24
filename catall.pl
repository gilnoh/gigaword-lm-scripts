#!/usr/bin/perl 

# This simple script gets a path, and cat them all simply to STDOUT 
use warnings;
use strict; 

die "usage: At least one argument needed; a file path with a wild card.\n(e.g. perl catall.pl \"./models/*.story\"). \nNote that you need quotation (e.g. \"./path/fileglob\") to surround your path.\nThe script will cat all of them to STDOUT. \n" unless ($ARGV[0]); 

my @ls = glob("$ARGV[0]"); 
foreach (@ls)
{
    open FILE, "<", $_; 
    print while (<FILE>); 
    close FILE; 
}
