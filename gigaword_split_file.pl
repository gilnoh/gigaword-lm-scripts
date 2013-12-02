#!/usr/bin/perl 

# read in the output file of a news-month (after) splitta,   
# and splits the monthly document into per-news documents 

use strict; 
use warnings; 

# clear trailing part of text.
our $CLEAN_TRAIL = 1; 

# (day as subdir. you *must* keep this option as 1) 
# (no longer optional) 
my $DAY_SUBDIR = 1; 

# read 
die "need two arguments. First: (file output from splitta with tokenizing), second: the output dir." unless ($ARGV[0]); 
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
	
	if ($DAY_SUBDIR) # AFP_201001/01/ AFP_201001/02  ... 
	{
	    $filename =~ /.+(\d\d)\./; 
	    my $day = $1; 
	    my $effective_outdir = $outputdir . "/" . $day; 
	    unless (-d $effective_outdir)
	    {
		mkdir $effective_outdir; 
	    }
	    open FILEOUT, ">", ($effective_outdir . "/" . $filename . "." . $ext) ; 
	}
	else
	{
	    open FILEOUT, ">", ($outputdir . "/" . $filename . "." . $ext) ; 
	}
    }

    # fixing tokenization error of Splitta (the end of sentence) 
    # case 1) Period (\w.$) at the end  -> (\w .$) 
    s/\.$/ \. /; 
    # case 2) Period space quote (\w. " $) at the end. -> (\w . " $) 
    s/\. " $/ \. " /;
    
    # the above (seems to) work well for AFP, at least. 
    # ALTERNATIVE: ... run splitta only for sentence split, 
    # and run another tokenization runner. (NOT for the moment). 

    if ($CLEAN_TRAIL)
    {
	s/ \. $//; 
	s/ \. " $/ "/;  
    }

    print FILEOUT lc($_); 
}

close FILEOUT; 
$count++; 
print STDERR "$count files generated in $outputdir\n"; 
