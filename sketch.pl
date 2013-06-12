# temporary sketch of the experiment, 

use warnings; 
use strict; 
use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file plucene_query solr_query P_t_index P_h_t_index); 
use octave_call; 
use Benchmark qw(:all); 
use POSIX qw(_exit); 

our $DEBUG = 2; 
set_num_thread(2); 
our $APPROXIMATE_WITH_TOP_N_HITS=4000; 

my $text = lc "A bus collision with a truck in Uganda has resulted in at least 30 fatalities and has left a further 21 injured"; 
my $hypothesis = lc "30 dies in a bus collision in Uganda"; 

if ($ARGV[0] and $ARGV[1])
{
    $text = $ARGV[0]; 
    $hypothesis = $ARGV[1]; 
}

# time in 
my $t0 = Benchmark->new; 
#my %r = P_t_multithread($text, 0.5, "./models/collection/collection.model", "./models/document"); 
##P_h_t_multithread($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document/afp_eng_2010"); 


## testing new P_t_index, with P_t_multithread_index 
#my $href = P_t_multithread_index($text, 0.5, "./models/collection/collection.model", "./models/document", "./models_index"); 
#my $href = P_t_index($text, 0.5, "./models/collection/collection.model", "./models/document"); 
#export_hash_to_file($href, "sketch_test.txt"); 

# The following two lines need octave. 
#my @a = values %{$href}; 
#print "\naverage logprob from the doc-models:", mean(\@a), "\n"; 

#P_h_t_multithread_index($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document", "./models_index");
P_h_t_index($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document");
#P_h_t_index($text, $hypothesis, 0.5, "./models/collection/collection.model", "./models/document");
#P_h_t_index($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document");

# time out
my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
$| = 1; # for _exit
print "the code took:", timestr($td), "\n"; 


