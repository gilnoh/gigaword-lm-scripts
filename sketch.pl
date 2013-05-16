# temporary sketch of the experiment, 

use warnings; 
use strict; 
use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file plucene_query); 
use octave_call; 
use Benchmark qw(:all); 
use POSIX qw(_exit); 

our $DEBUG = 2; 
set_num_thread(2); 
our $APPROXIMATE_WITH_TOP_N_HITS=4000; 

# test call on 2009 small set -- not that meaningful (since 2009 May doesn't have any aircraft accident, etc 
#my $text = "there was an airplane accident";  
#my $hypothesis = "everyone died"; 
#my $text = "the united arab emirates has given 1.43 million dollars to bangladeshi authorities to compensate children used as under-aged camel jockeys in the desert state , a minister said wednesday"; 
#my $hypothesis = "the united arab emirates paid bangladesh to compensate child abuse"; 
my $text = lc "A bus collision with a truck in Uganda has resulted in at least 30 fatalities and has left a further 21 injured"; 
my $hypothesis = lc "30 dies in a bus collision in Uganda"; 

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
#my %r = P_t_multithread($text, 0.5, "./models/collection/collection.model", "./models/document"); 
##P_h_t_multithread($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document/afp_eng_2010"); 

## Some tweaking for P_t_multithread_index
#my %r = P_t_multithread_index($text, 0.5, "./models/collection/collection.model", "./models/document/afp_eng_2009", "./models_index"); 
#export_hash_to_file(\%r, "sketch_test.txt"); 
#my @a = values %r; 
#print "\naverage logprob from the doc-models:", mean(\@a), "\n"; 

## Some sketch for P_h_t. 
#P_h_t_multithread($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document");

P_h_t_multithread_index($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document", "./models_index");

# time out
my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
print "the code took:", timestr($td), "\n"; 
_exit(0); 

# sub export_hash_to_file
# {
#     my %h = %{$_[0]}; 
#     my $filename = $_[1]; 
#     open FILE, ">", $filename; 
#     foreach (sort keys %h)
#     {
# 	print FILE "$_ \t $h{$_}\n"; 
#     }
#     close FILE;
# }
