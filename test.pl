use strict;
use warnings; 
use octave_call; 
use srilm_debug_read; 
use Test::Simple tests => 2; 

# lambda_sum 
my $l = 0.9; 
my @left = (0.1, 0.2); 
my @right = (0.02, 0.03); 
my $result = lambda_sum($l, \@left, \@right); 
ok($result == -1.7738); 

# read_debug3_p 
open FILE_C, "<", "./testdata/debug3_coll.out"; 
open FILE_D, "<", "./testdata/debug3_doc.out"; 

my @c = <FILE_C>; 
my @d = <FILE_D>; 
my @c_prob_seq = read_debug3_p(@c); 
my @d_prob_seq = read_debug3_p(@d); 
my $lambda = 0.5; 
$result = lambda_sum($lambda, \@d_prob_seq, \@c_prob_seq); 
print ($result); 
#ok(1); 
ok(($result - (-42.5641)) < 0.001); 
