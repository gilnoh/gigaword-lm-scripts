# Simple runner that calculates P( hypo | text ) for RTE3 (EOP format)
# XML file and report relevant values (like PMI-gain, PPL-gain,
# probabilities, etc)

# TODO? (BB value?  =  PPL( h | t ) / PPL(t / t) )

# Consider
# - do we need to normalize PMI? No.
# - Minus value is normalized, right? (right. per-word)
#   (Is this always a linear-relation to PMI?): hmm. Not sure. check.

use warnings;
use strict;
#use POSIX qw(_exit);
use Benchmark qw(:all);
#use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file $SOLR_URL); 
use condprob qw(:DEFAULT set_num_thread $DEBUG export_hash_to_file $SOLR_URL); 

my $lambda = 0.3;
#my $TRAINFILE = "./testdata/English_dev.xml";
#my $TESTFILE = "./testdata/English_test.xml";
my $TEMP_DIR = "./temp";
die "Usage: needs three arguments.\n\">perl runner.pl rte_filename start_num end_num\"\n perl runner.pl ./testdata/English_dev.xml 0 800" unless ($ARGV[2]);

my $RTEFILE = $ARGV[0];
die "unable to open file: $RTEFILE" unless (-r $RTEFILE);

my $START_ID = $ARGV[1] + 0;
my $END_ID = $ARGV[2] + 0;

die "start id out of bounds" if ($START_ID < 1 or $START_ID > 800);
die "end id out of bounds" if ($END_ID < 1 or $END_ID > 800);
die "end id must be bigger than start" if ($END_ID < $START_ID);

# PARAMETERS to set (for proto_condprob.pm) 
our $DEBUG=0; # well, turn it on for quality check. 
set_num_thread(2);
our $SOLR_URL = "http://localhost:9911/solr";
our $APPROXIMATE_WITH_TOP_N_HITS=4000;

# time in 
my $t0 = Benchmark->new;

# read data 
my ($t_aref, $h_aref, $d_aref) = read_rte_data($RTEFILE);
#for(my $i=0; $i < scalar(@$t_aref); $i++)
#{
#    print "id: ", ($i+1), "\t", $d_aref->[$i] ,"\n"; 
#    print "T: ", $t_aref->[$i]; 
#    print "H: ", $h_aref->[$i]; 
#}

# now select one
for (my $pair_id = $START_ID; $pair_id <= $END_ID; $pair_id++)
{
  my $id = $pair_id - 1; # starting from 0.

  my $text = call_splitta($t_aref->[$id]);
  my $hypo = call_splitta($h_aref->[$id]);
  print STDERR "Processing id $id;\n";
  my ($collection_p_h, $model_p_h, $model_p_h_given_t, $h_words, $h_sents) = condprob_h_given_t($hypo, $text, $lambda, "./models/collection/collection.model", "./models/document");

  #$| = 1;

  my $pmi = "pmi(TBD)";
  my $bb = "bb_val(TBD)";
  my $ppl_minus = "minus(TBD)";
  my $target_ppl = calc_ppl($model_p_h_given_t, $h_words, $h_sents);
  my $uncond_ppl = calc_ppl($model_p_h, $h_words, $h_sents);
  $ppl_minus = $uncond_ppl - $target_ppl;
  $pmi = $model_p_h_given_t - $model_p_h;
  print "$pair_id|GOLD:$d_aref->[$id]|, $bb, $pmi, $target_ppl, $ppl_minus, $h_words, $h_sents, $model_p_h_given_t, $model_p_h\n";

}
# time stamp
my $t1 = Benchmark->new;
my $td = timediff($t1, $t0);
print STDERR "the code took:", timestr($td), "\n";
#exit(0);
###
###
###

# call splitta for tokenization ... 
# sub call_splitta 
# {
#     print STDERR "tokenization ..."; 
#     my $s = shift; 

#     # write a temp file
#     my $file = $TEMP_DIR . "/splitta_input.txt"; 
#     open OUTFILE, ">", $file; 
#     print OUTFILE $s; 
#     close OUTFILE; 
    
#     # my $splitted_output = "$temp_dir" . $file_basename . ".splitted"; 
#     `python ./splitta/sbd.py -m ./splitta/model_nb -t -o $TEMP_DIR/splitted.txt $file 2> /dev/null`;
#     print STDERR " done\n"; 

#     open INFILE, "<", $TEMP_DIR . "/splitted.txt"; 
#     my $splitted=""; 
#     while(<INFILE>)
#     {
# 	# NOTE: this process must be the same as training data generated
# 	# in gigaword_split_file.pl 

# 	# fixing tokenization error of Splitta (the end of sentence) 
# 	# case 1) Period (\w.$) at the end  -> (\w .$) 
# 	s/\.$/ \. /; 
# 	# case 2) Period space quote (\w. " $) at the end. -> (\w . " $) 
# 	s/\. " $/ \. " /;

# 	$splitted .= $_; 
#     }
#     close INFILE; 

#     return lc($splitted); 
# }


# reading EOP RTE file. 
sub read_rte_data
{
    # not generic but, good for current data 
    my $filename = shift; 
    open FILE, "<", $filename or die "unable to read $filename"; 
    
    my @t;
    my @h; 
    my @gold; 
  
    while (<FILE>)
    {
	next unless ($_ =~ /<pair id=.+ entailment="(.+?)"/); 
	# now a pair: get next two lines 
	{
	    my $gold_decision = $1; 
	    my $tline = <FILE>; 
	    my $hline = <FILE>; 
	    # remove head / tail tags 
	    $tline =~ s/^\s+<t>//; 
	    $tline =~ s/<\/t>$//; 

	    $hline =~ s/^\s+<h>//; 
	    $hline =~ s/<\/h>$//; 

	    # dcode 
	    #print $tline, "\n"; 
	    #print $hline, "\n"; 
	    #die; 
	    push @t, $tline; 
	    push @h, $hline; 
	    push @gold, $gold_decision; 
	}
    }    
    die "Eh, need to be called within an array context" unless defined wantarray; 
    return (\@t, \@h, \@gold); 
}
