# temporary sketch of the experiment, 

use warnings; 
use strict; 
use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS); 
use octave_call; 
use Benchmark qw(:all); 

our $DEBUG = 2; 
set_num_thread(2); 
# test call on 2009 small set 
# (not meaningful at all, since none of May 2009 holds any event on plane crash) just as functional OKAY-ness. Too small corpus that does not really have those terms) 
my $text = "there was an airplane accident";  
my $hypothesis = "everyone died"; 

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




# time in 
my $t0 = Benchmark->new; 
our $APPROXIMATE_WITH_TOP_N_HITS=100000; 
#my %r = P_t_multithread($text, 0.5, "./models/collection/collection.model", "./models/document/afp_eng_2009"); 
 my %r = P_t_multithread_index($text, 0.5, "./models/collection/collection.model", "./models/document/afp_eng_2009", "./models_index"); 
#P_h_t_multithread($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document/afp_eng_2010"); 

my @a = values %r; 
print "\naverage logprob from the doc-models:", mean(\@a), "\n"; 


# time out
my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
print "the code took:", timestr($td), "\n"; 

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
