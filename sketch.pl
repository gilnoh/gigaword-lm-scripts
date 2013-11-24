# temporary sketch of the experiment, 

use warnings; 
use strict; 
#use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file plucene_query solr_query P_t_index P_h_t_index $SOLR_URL); 
use condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file P_t_index P_h_t_index $SOLR_URL); 
use octave_call; 
use Benchmark qw(:all); 

our $DEBUG = 0; # no debug output 
our $SOLR_URL = "http://127.0.0.1:9911/solr"; 
set_num_thread(4); 
our $APPROXIMATE_WITH_TOP_N_HITS=4000; 

my $TEMP_DIR = "./temp"; # for splitta, text splitter. 
my $text = lc "A bus collision with a truck in Uganda has resulted in at least 30 fatalities and has left a further 21 injured"; 
my $hypothesis = lc "30 dies in a bus collision in Uganda"; 

if ($ARGV[0] and $ARGV[1])
{
    $text = call_splitta($ARGV[0]); 
    $hypothesis = call_splitta($ARGV[1]); 
}

# time in 
my $t0 = Benchmark->new; 
# arguments: (context, text, lamda, collection model file, document models top path)
#P_h_t_index($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document");
condprob_h_given_t($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document");

# time out
my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
print "the code took:", timestr($td), "\n"; 
exit(); 

# 2nd run, real, normal expected time for pairs. 
P_h_t_index($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document");

my $t2 = Benchmark->new; 
$td = timediff($t2, $t1); 
print "2nd time (the normal time) it took: ", timestr($td), "\n"; 


# utility: call splitta for tokenization ... 
sub call_splitta 
{
    print STDERR "tokenization ..."; 
    my $s = shift; 

    # write a temp file
    my $file = $TEMP_DIR . "/splitta_input.txt"; 
    open OUTFILE, ">", $file; 
    print OUTFILE $s; 
    close OUTFILE; 
    
    # my $splitted_output = "$temp_dir" . $file_basename . ".splitted"; 
    `python ./splitta/sbd.py -m ./splitta/model_nb -t -o $TEMP_DIR/splitted.txt $file 2> /dev/null`;
    print STDERR " done\n"; 

    open INFILE, "<", $TEMP_DIR . "/splitted.txt"; 
    my $splitted=""; 
    while(<INFILE>)
    {
	# NOTE: this process must be the same as training data generated
	# in gigaword_split_file.pl 

	# fixing tokenization error of Splitta (the end of sentence) 
	# case 1) Period (\w.$) at the end  -> (\w .$) 
	s/\.$/ \. /; 
	# case 2) Period space quote (\w. " $) at the end. -> (\w . " $) 
	s/\. " $/ \. " /;

	$splitted .= $_; 
    }
    close INFILE; 

    return lc($splitted); 
}
