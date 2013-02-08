#!/usr/bin/perl 

use strict; 
use warnings; 

my $NGRAM_COUNT_COMMAND="ngram-count"; 
my $NGRAM_COUNT_OPTIONS="";  

# > ngram-count -text [filename] -lm [modelname] 
# this will generate model with default (3-gram, default discount, etc) 

# get a path 
die "Usage: At least one argument needed; a file path with a wild card.\n(e.g. perl runner.pl \"./output/*.story\"). \nNote that you need quotation (e.g. \"./path/fileglob\") to surround your path.\n" unless ($ARGV[0]); 

# sanity check 
my $x = `$NGRAM_COUNT_COMMAND`; 
die "Unable to run the ngram-count executable. Maybe not in path?\n" if (!defined($x));  

# glob them 
my @ls = glob("$ARGV[0]"); 

# for each, run ngram-count for each file with the set option 
my $file_count=0; 
foreach (@ls)
{
    my $inputfile = $_; 
    my $outputmodel = $inputfile . ".model"; 
    my $command = $NGRAM_COUNT_COMMAND . " -text " . $inputfile . " -lm " . $outputmodel . ">> stdout 2>> stderr"; 
    `$command`; 
    
    $file_count++; 
    print STDERR "." unless ($file_count % 100); 
}

print STDERR "processed and generated $file_count files\n"; 
