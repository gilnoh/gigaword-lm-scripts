#!/usr/bin/perl 

# TODO: 
# - get input as mulitple gz (Gigaword) files. 
# - ... and process and store them on a directory
# - (ANOTHER SCRIPT: ... also calls ngram LM tools on them) 

use warnings; 
use strict; 
use File::Basename; 

die "Need two arguments: 1) gigaword file name, 2) output dir" unless ($ARGV[1]); 

die "Unable to read file $ARGV[0]" unless (-e $ARGV[0]); 
die "Unable to access dir $ARGV[1]" unless (-d $ARGV[1]); 

my $temp_dir = "./temp/"; 
my $file_path = $ARGV[0]; 
#my $file_basename; 
my $file_basename = fileparse($ARGV[0]); 
my $output_dir = $ARGV[1]; 


die "Need to be run on the script dir" unless (-r "dexml.pl"); 

## 
print STDERR "Working on $file_basename\n"; 

## dexml, save it as .dexml 
my $redirect_output = "$temp_dir" .  $file_basename . ".dexml"; 
`perl gigaword_dexml.pl $file_path > $redirect_output`; 
print STDERR "Unzipped and de-XMLed. Calling sentence splitter+tagger\n"; 

## run sentence splitter (+ tokenier), save it .splitted 
my $splitted_output = "$temp_dir" . $file_basename . ".splitted"; 
`python ./splitta/sbd.py -m ./splitta/model_nb -t -o $splitted_output $redirect_output`;
print STDERR "Sentence Splitter Done, dividing into per document files\n"; 

## divide it into doc per file, on output dir 
#perl divide_files.pl ./temp/t.splitted ../inputdata/afp_eng_2010/
`perl gigaword_split_file.pl $splitted_output $output_dir`; 

