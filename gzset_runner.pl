#!/usr/bin/perl 

# This script uses gz_to_newsperfil.pl, to convert a set of 
# GigaWord files into one 

use warnings;
use strict;
use File::Basename; 

my $SCRIPT_TO_RUN="gz_to_newsperfile.pl"; 
my $CREATE_SUBDIRECTORY_AGENTYEAR=1; 
   # if 1, subdirectory with the "year" generated 
   # if 0, all in the output dir 
   # WARNING: subdirectories (1) are better, since it gets really slow 
   # with more than 100K files in a directory. 
my $OUTPUT_PATH_BASE="./models/document"; 
die "needs a list of Gigaword gz files" unless ($ARGV[0]); 

foreach(@ARGV)
{
    my $filename = $_; 
    my $outpath;
    if ($CREATE_SUBDIRECTORY_AGENTYEAR)
    {
	my $basename = fileparse($filename); 
	$basename =~ /(.+)\d\d\./; 
	my $agent_year = $1; 
	$outpath = $OUTPUT_PATH_BASE . "/" . $agent_year; 
	
	unless (-d $outpath) 
	{
	    mkdir $outpath; 
	}

    }
    else
    {
	$outpath = $OUTPUT_PATH_BASE; 
    }

    print STDERR "$filename  -to->  $outpath\n";
    `perl $SCRIPT_TO_RUN $filename $outpath`; 
}




