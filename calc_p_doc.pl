#!/usr/bin/perl 

use warnings;
use strict; 

use srilm_debug_read;  
use octave_call; 

# this script gets one string, and calculates its probabiltiy  P(t) 
# as defined over the collection. 

## OUTPUT 
# output will be on STDOUT (?) 
# P_final(t)  \n 
# sum(P_d(t)) \n 
# docname   \t   P_doc(t)   \n ... [each line holds p_doc(t)] 



#die "Usage: needs one argument; one (tokenized) string of a sentence\n" unless ($ARGV[0]);





#####
# some test codes 
#####

my $lambda=0.5; 
my @left = (1,2,3); 
my @right= (4,5,6); 
lambda_sum($lambda, \@left, \@right);  



# open FILE, "<", "./output/t"; 
# my @lines = <FILE>; 
# my @log = read_debug3_log(@lines); 
# my $v=0;  
# foreach (@log)
# {
#     print $_, "\n"; 
# }

