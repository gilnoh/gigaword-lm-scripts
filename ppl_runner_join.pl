# this small script runs and calculate ppl of each sentence, by calling
# P_t_index(s1+ ... + s_n + ... s_n+x)#

use warnings; 
use strict; 
use Benchmark qw(:all); 
use condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS $NOHIT_L0_FILL export_hash_to_file);


## configurable values
##

# exported from condprob.pm
our $DEBUG = 0;
our $SOLR_URL = "http://127.0.0.1:9911/solr";
set_num_thread(4);
our $APPROXIMATE_WITH_TOP_N_HITS=4000;

# own configuration values
#
# - method to select context
our $SIZE_SENT_WINDOW = 2; # window of +-n

# - pass test document  with less than N sentences.
our $DOC_MIN_NUM_SENTENCES = 5;

# end of configurable values

## global (if any)
##
my $instance_id = "ppl1";

##  test usage of P_t_joint
# my $text = lc "we all feel the same \nwe feel very close to him ";
# my ($P_coll, $P_model_joint, $count_nonOOV, $count_sent  ) = P_t_joint($text, 0.5, "./models/collection/collection.model", "./models/document", $instance_id);
# exit();


## code start
##

unless ($ARGV[0] && $ARGV[1])
{
    die "requires at least two or more arguments\n   - instance_id (unique id of this run. any string, but unique)\n   - one (or more) text file names (the file as same as to be passed for SRILM -ppl).\n example: > perl ppl_runner_joint.pl \"myrun1\" ./testdata/*.story\n";
}

# time in 
my $t0 = Benchmark->new; 
$instance_id = shift @ARGV; 
my @files = @ARGV; 

# variables to store all
my $total_P_coll = 0;
#my $total_P_model = 0;
my $total_P_model_joint = 0;
my $total_count_nonOOV = 0;
my $total_count_sent = 0;

my $number_of_processed_doc = 0;

foreach my $filename (@files)
{
    die "unable to read file $filename\n" unless (-r $filename); 
    # we got one file; already tokenized and sentence splitted. 
    print $filename, "\n";
    my $raw_content;
    open INFILE, "<", $filename; 
    $raw_content .= $_ while (<INFILE>);
    close INFILE;
    my @temp = split /\n/, $raw_content;
    my @sentences;
    foreach (@temp) # prepare text 
    {
	#remove all empty lines, so "real lines only"
	next unless (/\S/); # next if whitespce only
	next unless (/\w/); # next if there's no alphanumeric char. 

        push @sentences, $_;
    }

    # calling of the main method.
    # skip if num sentence is less than minimum (why? too few sentence makes
    # it harder to extract context parts. (e.g. prev-3, next-3, etc)
    if ( (scalar @sentences) < $DOC_MIN_NUM_SENTENCES )
    {
	print STDERR "$filename is shorter than $DOC_MIN_NUM_SENTENCES sentences. passing\n"; 
	next; 
    }

    my ($sum_P_coll, $sum_P_model_joint, $sum_count_nonOOV, $sum_count_sent) = ppl_one_doc_joint(@sentences);

    # sumup
    $total_P_coll += $sum_P_coll; 
    #$total_P_model += $sum_P_model; 
    $total_P_model_joint += $sum_P_model_joint;
    $total_count_nonOOV += $sum_count_nonOOV; 
    $total_count_sent += $sum_count_sent; 
    $number_of_processed_doc++; 
}

print "====\n";
print "====\n"; 
print "Number of documents processed: $number_of_processed_doc\n"; 
print "$total_P_coll \t $total_P_model_joint \t $total_count_nonOOV \t $total_count_sent\n"; 
print "All Collection logprob: $total_P_coll (ppl: ", calc_ppl($total_P_coll, $total_count_nonOOV, $total_count_sent), ")\n";
#print "All model logprob: $total_P_model (ppl: ", calc_ppl($total_P_model, $total_count_nonOOV, $total_count_sent), ")\n";
print "All conditioned model logprob: $total_P_model_joint (ppl: ", calc_ppl($total_P_model_joint, $total_count_nonOOV, $total_count_sent), ")\n";

# time out
my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
print "the code took:", timestr($td), "\n"; 

sub ppl_one_doc_joint
{
    my @sent = @_;
    my $count = scalar (@sent);

    my $sum_P_coll;
#    my $sum_P_model;
    my $sum_P_model_joint;
    my $sum_count_nonOOV;
    my $sum_count_sent;

    # ok. we will calculate conditional probability
    # with the number $SIZE_SENT_WINDOW
    for(my $i=$SIZE_SENT_WINDOW; $i < ($count - $SIZE_SENT_WINDOW); $i++)
      {
        my $text= ""; 
        for (my $j=($i - $SIZE_SENT_WINDOW); $j < ($i + $SIZE_SENT_WINDOW +1); $j++)
        {
           $text .= $sent[$j] . "\n";
        }

        # now text prepared. call.
        my ($P_coll, $P_model_joint, $count_nonOOV, $count_sent  ) = P_t_joint($text, 0.5, "./models/collection/collection.model", "./models/document", $instance_id);

	print "$P_coll \t $P_model_joint \t $count_nonOOV \t $count_sent\n";

	# undef check. (non word setnence like "..." can make undef)
	if (defined $P_model_joint)
	{
	    # sum 
	    $sum_P_coll += $P_coll;
	    $sum_P_model_joint += $P_model_joint;
	    $sum_count_nonOOV += $count_nonOOV;
	    $sum_count_sent += $count_sent;
	}
	else
	{
	    warn "non-words only, or all OOV sentence, passing the sentence\n"; 
	    print "non-words only, or all OOV sentence, passing the sentence\n" 
	}

    } # for $i < $count 
    # output for this file 
    print "Sum of this doc:\n"; 
    print "$sum_P_coll \t $sum_P_model_joint \t $sum_count_nonOOV \t $sum_count_sent\n"; 
    print "Total Collection logprob: $sum_P_coll (ppl: ", calc_ppl($sum_P_coll, $sum_count_nonOOV, $sum_count_sent), ")\n";
    #print "Total model logprob: $sum_P_model (ppl: ", calc_ppl($sum_P_model, $sum_count_nonOOV, $sum_count_sent), ")\n";
    print "Joint model logprob: $sum_P_model_joint (ppl: ", calc_ppl($sum_P_model_joint, $sum_count_nonOOV, $sum_count_sent), ")\n";

    return ($sum_P_coll, $sum_P_model_joint, $sum_count_nonOOV, $sum_count_sent);
}
