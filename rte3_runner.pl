# Simple runner that calculates P( hypo | text ) for RTE3 (EOP format)
# XML file and report relevant values (like PMI-gain, PPL-gain,
# probabilities, etc)

# Consider
#   relationship between PMI to ppl_gain (same? or not?) 

# List of possible (sketch-oriented) features 

## - From sketch (probably P() & PPL() are duplicated)  
## P_coll(h) 
## P_model(h)
## P_coll(t)
## P_model(t)
## P_model(h|t)
## PMI(h,t) 
# PMI(h,t) / (h_len) 
# PMI(h,t) / (t_len + h_len) 
# PPL(t)
# PPL(h)
# PPL(h|t)
# PPL(h|t) - PPL(h)  
# PPL(h|t) / PPL(h) 

## - From previous 
# bb (missing) (not gonna cover) 
# pmi (covered) 
# pmi / h_len  (covered) 
# PPL(h|t)     (covered) 
# PPL(h) - PPL(h|t) 
# ( PPL(h) - PPL(h|t) )  / PPL(h)  -- A 
#     prolly better just use PPL(h|t) / PPL(h) (== 1 - A) 
# PPL(t) 

use warnings;
use strict;
#use POSIX qw(_exit);
use Benchmark qw(:all);
#use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file $SOLR_URL); 
use condprob qw(:DEFAULT set_num_thread $DEBUG export_hash_to_file $SOLR_URL calc_ppl); 

my $lambda = 0.9;
#my $TRAINFILE = "./testdata/English_dev.xml";
#my $TESTFILE = "./testdata/English_test.xml";
my $TEMP_DIR = "./temp";
die "Usage: needs four arguments.\n\">perl runner.pl rte_filename start_num end_num run_id(any unique string)\"\n perl runner.pl ./testdata/English_dev.xml 1 800 myrun1\n" unless ($ARGV[3]);

my $RTEFILE = $ARGV[0];
die "unable to open file: $RTEFILE" unless (-r $RTEFILE);

my $START_ID = $ARGV[1] + 0;
my $END_ID = $ARGV[2] + 0;
my $RUN_ID = $ARGV[3]; 

die "start id out of bounds" if ($START_ID < 1 or $START_ID > 800);
die "end id out of bounds" if ($END_ID < 1 or $END_ID > 800);
die "end id must be bigger than start" if ($END_ID < $START_ID);

# PARAMETERS to set (for proto_condprob.pm) 
our $DEBUG=0; # well, turn it on for quality check. 
set_num_thread(4);
our $SOLR_URL = "http://localhost:9911/solr";
our $APPROXIMATE_WITH_TOP_N_HITS=4000;

# time in 
my $t0 = Benchmark->new;

# read data 
my ($t_aref, $h_aref, $d_aref) = read_rte_data($RTEFILE);

# debug output 
#for(my $i=0; $i < scalar(@$t_aref); $i++)
#{
#    print "id: ", ($i+1), "\t", $d_aref->[$i] ,"\n"; 
#    print "T: ", $t_aref->[$i]; 
#    print "H: ", $h_aref->[$i]; 
#}

## print header (CVS format, first line as column names) 
print "id, gold, P_coll(h), P_model(h), P_coll(t), P_model(t), P_model(h|t), PMI(h;t), PPL(t), PPL(h), PPL(h|t), PPLgain,";
print "\n"; 

# now select one
for (my $pair_id = $START_ID; $pair_id <= $END_ID; $pair_id++)
{
  my $id = $pair_id - 1; # id actually is starting from 0.

  my $text = call_splitta($t_aref->[$id]);
  my $hypo = call_splitta($h_aref->[$id]);
  print STDERR "Processing id $pair_id;\n";

  # if splitta fails: (RTE3 dev 141, hypo) 
  warn "SPLITTA failed! ==> fallback to lc(string).\n" unless($text and $hypo); 
  $text = lc($t_aref->[$id]) unless($text); 
  $hypo = lc($h_aref->[$id]) unless($hypo); 
  print STDERR "text: $text\n"; 
  print STDERR "hypo: $hypo\n"; 
  my ($collection_p_h, $model_p_h, $model_p_h_given_t, $h_words, $h_sents, $collection_p_t, $model_p_t, $t_words, $t_sents) = condprob_h_given_t($hypo, $text, $lambda, "./models/collection/collection.model", "./models/document", $RUN_ID);

  # #my $bb = "bb_val(TBD)";   # (BB value?  =  PPL( h | t ) / PPL(t / t) )
  # my $target_ppl = calc_ppl($model_p_h_given_t, $h_words, $h_sents);
  # my $uncond_ppl = calc_ppl($model_p_h, $h_words, $h_sents);
  # my $ppl_minus = $uncond_ppl - $target_ppl;
  # my $ppl_gain = ($uncond_ppl - $target_ppl) / $uncond_ppl; 
  # my $pmi = $model_p_h_given_t - $model_p_h;
  # my $pmi_per_hword = $pmi / ($h_words + $h_sents); 
  # my $text_side_ppl = calc_ppl($model_p_t, $t_words, $t_sents); 
  # print "$pair_id|GOLD:$d_aref->[$id]|, $bb, $pmi, $pmi_per_hword, $target_ppl, $ppl_minus, $ppl_gain, $text_side_ppl\n";

  ## prepare values to print. 
  # P_coll(h) 
  my $out_p_coll_h = $collection_p_h;
  # P_model(h)
  my $out_p_model_h = $model_p_h; 
  # P_coll(t)
  my $out_p_coll_t = $collection_p_t; 
  # P_model(t) 
  my $out_p_model_t = $model_p_t; 
  # P_model(h|t) 
  my $out_p_model_h_given_t = $model_p_h_given_t; 
  
  # PMI(h;t)
  my $out_pmi_h_t = $model_p_h_given_t - $model_p_h;

  # PPLs 
  my $t_ppl = calc_ppl($model_p_t, $t_words, $t_words); 
  my $h_ppl = calc_ppl($model_p_h, $h_words, $h_sents); 
  my $h_given_t_ppl = calc_ppl($model_p_h_given_t, $h_words, $h_sents); 
  my $ppl_gain = ($h_ppl - $h_given_t_ppl) / $h_ppl; # -1 ~ 1 value


  # all prepared. print 
  print "$pair_id, $d_aref->[$id], $out_p_coll_h, $out_p_model_h, $out_p_coll_t, $out_p_model_t, $out_p_model_h_given_t, $out_pmi_h_t, $t_ppl, $h_ppl, $h_given_t_ppl, $ppl_gain,"; 
  print "\n"; 


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
