#!/usr/bin/perl
# TODO: all output as lower case. 

use warnings;
use strict; 

die "Usage: perl dexml.pl [giga word file]" unless ($ARGV[0] and -r $ARGV[0]); 

my $infile = $ARGV[0]; 
if ($infile =~ /\.gz$/)
{
    open (IN, "gunzip -c $infile |") || die "can't open pipe to $infile"; 
}
else 
{
    open (IN, $infile) || die "can't open $infile"; 
}

while(<IN>)
{
    # "header" mode --- process before <TEXT> 
    while(<IN>)
    {
	if (/<DOC id=/)
	{
	    print; 
	    print "\n"; 
	}
	last if (/<TEXT>/); 
	if (/<HEADLINE>/)
	{
	    my $next = <IN>;  print $next; 
	}

    }
    print "\n"; # now text 

    # "text" mode --- process <TEXT> content 
    while(<IN>)
    {
	next if (/<P>/); 
	if (/<\/P>/) 
	{
	    print "\n"; 
	    next; 
	}
	last if (/<\/TEXT>/); 
	print; 

    }
    print "\n";     
}
