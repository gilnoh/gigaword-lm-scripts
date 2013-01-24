#!/usr/bin/perl 

# read in the output file of a news-month (after) splitta,   
# and splits the monthly document into per-news documents 

use strict; 
use warnings; 

# read 
die "need an argument (file output from splitta with tokenizing)" unless ($ARGV[0]); 
die "need the output dir (where each sentence splitted news story will be unpacked)" unless ($ARGV[1]); 
die "unable to read file $ARGV[0]"  unless (-r $ARGV[0]); 
die "unable to access directory $ARGV[1]" unless (-d $ARGV[1]); 

open FILEIN, "<$ARGV[0]"; 
my $outputdir = $ARGV[1]; 
my $count=0; 
while(<FILEIN>)
{
    # check DOC mark 
    if (/^<DOC id=/)
    {
	$count++; 
	close FILEOUT; 
	/type= " (\S+) "/; 
	my $ext = $1; 

	s/<DOC id= " (\S+) ".+?>//; 
	my $filename = $1; 
	open FILEOUT, ">", ($outputdir . "/" . $filename . "." . $ext) ; 

    }
    print FILEOUT lc($_); 
}

close FILEOUT; 
$count++; 
print STDERR "$count files generated in $outputdir\n"; 
