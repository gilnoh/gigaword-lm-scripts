# Simple runner that calculates two baseline methods 
# for RTE3 data XML file and report relevant values 
# This baseline code reports the following values
#  - mean word PMI 
#  - product best-per-word conditional prob. 

use warnings;
use strict;
use Benchmark qw(:all);
use condprob qw(:DEFAULT set_num_thread $DEBUG export_hash_to_file $SOLR_URL mean_allword_pmi product_best_word_condprob mean_best_wordPMI); 

# PARAMETERS to set (for condprob.pm) 
our $DEBUG=0; # well, turn it on for quality check. 
set_num_thread(4);
our $SOLR_URL = "http://localhost:9911/solr";
our $APPROXIMATE_WITH_TOP_N_HITS=4000;
#my $lambda = 0.2;
my $TEMP_DIR = "./temp";
$| =1; # flush always

die "Usage: needs three arguments.\n\">perl runner.pl rte_filename start_num end_num\"\n perl runner.pl ./testdata/English_dev.xml 1 800 \n" unless ($ARGV[2]);

my $RTEFILE = $ARGV[0];
die "unable to open file: $RTEFILE" unless (-r $RTEFILE);

my $START_ID = $ARGV[1] + 0;
my $END_ID = $ARGV[2] + 0;
my $RUN_ID = "rte_baseline"; 

die "start id out of bounds" if ($START_ID < 1 or $START_ID > 800);
die "end id out of bounds" if ($END_ID < 1 or $END_ID > 800);
die "end id must be bigger than start" if ($END_ID < $START_ID);

# time in 
my $t0 = Benchmark->new;

# read data 
my ($t_aref, $h_aref, $d_aref) = read_rte_data($RTEFILE);


## print header (CVS format, first line as column names) 
#print "id, gold, P_coll(h), P_model(h), P_coll(t), P_model(t), P_model(h|t), PMI(h;t),";
#print "\n"; 
print "id, gold, meanPMI, norm-prod bestCondProd, raw-prod bestCondProd, mean bestPMI, wgt-mean bestPMI"; 
print "\n"; 

# now select one
for (my $pair_id = $START_ID; $pair_id <= $END_ID; $pair_id++)
{
  my $id = $pair_id - 1; # id actually is starting from 0.

  my $text = call_splitta($t_aref->[$id], $RUN_ID);
  my $hypo = call_splitta($h_aref->[$id], $RUN_ID);
  print STDERR "Processing id $pair_id;\n";

  # if splitta fails: (RTE3 dev 141, hypo) 
  warn "SPLITTA failed! ==> fallback to lc(string).\n" unless($text and $hypo); 
  $text = lc($t_aref->[$id]) unless($text); 
  $hypo = lc($h_aref->[$id]) unless($hypo); 
  print STDERR "text: $text\n"; 
  print STDERR "hypo: $hypo\n"; 

  my $meanPMI = mean_allword_pmi($text, $hypo); 
  my ($word_logprob_norm, $word_logprob_raw) = product_best_word_condprob($text, $hypo);  
  my ($mean_best_PMI, $weighted_mean_best_PMI) = mean_best_wordPMI($text, $hypo); 
  # all prepared. print 
  print "$pair_id, $d_aref->[$id], $meanPMI, $word_logprob_norm, $word_logprob_raw, $mean_best_PMI, $weighted_mean_best_PMI";
  print "\n"; 
}
# time stamp
my $t1 = Benchmark->new;
my $td = timediff($t1, $t0);
print STDERR "the code took:", timestr($td), "\n";


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
