#!/usr/bin/perl 

use strict; 
use warnings; 

my $NGRAM_COUNT_COMMAND="ngram-count"; 
my $NGRAM_COUNT_OPTIONS=" -write-binary-lm ";  # save as binary models, saves loading time, but does not (should not) affect any result 

# > ngram-count -text [filename] -lm [modelname] [additional options]
# this will generate model with default (3-gram, default discount, etc), if no additional option is affecting model related parameters. 

# get a path 
die "Usage: At least one argument needed; a dir path.\n(e.g. perl perstory_runner.pl \"./models/document\"). \nThe script will build one LM for each .story news file in the path's subdirs\n" unless ($ARGV[0]); 

# sanity check 
my $x = `$NGRAM_COUNT_COMMAND`; 
die "Unable to run the ngram-count executable. Maybe not in path?\n" if (!defined($x));  

my $toppath = $ARGV[0]; 
opendir (my $dh, $toppath) or die "can't open dir $ARGV[0]\n"; 
my @subdir; # will hold all subdirectories of the given path 
foreach (readdir($dh))
{
    next if ( ($_ eq "..") ); 
    my $path = $toppath . "/" . $_; 
    push @subdir, $path if (-d $path); 

    # push sub-sub dir, if any 
    if (-d $path)
    {
	unless ($_ eq ".")
	{
	    opendir (my $dsubh, $path) or die "can't open dir $path\n"; 
	    foreach (readdir($dsubh))
	    {
		next if ( ($_ eq "..") or ($_ eq ".")); 
		push @subdir, ($path . "/" . $_); 
	    }
	    close $dsubh; 
	}
    } # end sub-sub
}
close $dh; 
print STDERR "$toppath has ", scalar (@subdir), " dirs (subdirs + itself) to follow. For each of the .story, one LM will be built.\n";

my $file_count=0; 

foreach my $d (@subdir) 
{
    print STDERR "working on $d "; 
    # glob the files in the dir. 
    my @ls = glob($d . "/*.story"); 
    print STDERR scalar(@ls), " files\n"; 

    # for each, run ngram-count for each file with the set option 
    foreach (@ls)
    {
	my $inputfile = $_; 
	my $outputmodel = $inputfile . ".model"; 
	my $command = $NGRAM_COUNT_COMMAND . " -text " . $inputfile . " -lm " . $outputmodel . $NGRAM_COUNT_OPTIONS . ">> stdout 2>> stderr"; 
	`$command`; 
    
	$file_count++; 
	print STDERR "." unless ($file_count % 100); 
    }
    print STDERR "\n"; 
}
print STDERR "processed and generated $file_count model files in total\n"; 
