# temporary sketch of the experiment, 

use warnings; 
use strict; 
use proto_condprob qw(:DEFAULT set_num_thread); 
use octave_call; 

# test call on 2009 small set 

# (meaningless, if those text and hypothesis is not observable in the 2009 MAY) 
# Try with something that appears there. So see how distinctive they are in 
# terms of P_t and P_h 
my $text = "there was an airplane accident";  
my $hypothesis = "everyone died"; 

# what would be average of H(t|t)? : not sure. 24 (2 words) 316 (20+ words), related to the length? 
# train something according to gain, T length, H length, 


# my %r = P_t($text); 
# my %r = P_t_multithread($text); 
# print "Done\n"; 
# export_hash_to_file(\%r, "Pt_from_sketch.txt"); 
# my @a = values %r;
# print "Average logprob from the doc-models: ", mean(\@a), "\n"; 

## P_h_t_multithread call arguments 
# argument: hypothesis, text, lambda, collection model path, document models
# output (return): 
# ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ). 

P_h_t_multithread($hypothesis, $text); 

sub export_hash_to_file
{
    my %h = %{$_[0]}; 
    my $filename = $_[1]; 
    open FILE, ">", $filename; 
    foreach (sort keys %h)
    {
	print FILE "$_ \t $h{$_}\n"; 
    }
    close FILE;
}
