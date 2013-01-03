#!/usr/bin/perl 

# read in the output file of splitta,  
# 

use strict; 
use warnings; 

# read 
die "need an argument (file output from splitta with tokenizing)" unless ($ARGV[0]); 
die "unable to read file $ARGV[0]"  unless (-r $ARGV[0]); 

open FILEIN, "<$ARGV[0]"; 

while(<FILEIN>)
{
    # check DOC mark 
    if (/^<DOC id=/)
    {
	
	# TODO: skip a non-news (non-story) articles? 
	close FILEOUT; 
	/type= " (\S+) "/; 
	my $ext = $1; 

	s/<DOC id= " (\S+) ".+?>//; 
	my $filename = $1; 
	open FILEOUT, ">", ($filename . "." . $ext) ; 

    }
    print FILEOUT $_; 
}

close FILEOUT; 
