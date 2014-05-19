# a runner script for MSR paraphrase corpus runner
# 

use warnings;
use strict;
#use POSIX qw(_exit);
use Benchmark qw(:all);
#use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file $SOLR_URL); 
use condprob qw(:DEFAULT set_num_thread $DEBUG export_hash_to_file $SOLR_URL); 

# PARAMETERS to set (for proto_condprob.pm) 
our $DEBUG=0; # well, turn it on for quality check. 
set_num_thread(4);
our $SOLR_URL = "http://localhost:9911/solr";
our $APPROXIMATE_WITH_TOP_N_HITS=4000;

# local parameter
my $lambda = 0.2;

# usage check 
die "Usage: needs four arguments.\n\">perl runner.pl msr_filename start_num end_num run_id(any unique string)\"\n perl runner.pl ./testdata/msr_paraphrase_test.txt 1 1725 myrun1\n" unless ($ARGV[3]);

my $inputfile = $ARGV[0]; 

# read data 
my ($gold_aref, $t_aref, $h_aref) = MSRPC_reader($inputfile); 

my $datasize = scalar (@{$gold_aref}); 

my $START_ID = $ARGV[1] + 0;
my $END_ID = $ARGV[2] + 0;
my $RUN_ID = $ARGV[3]; 

die "start id out of bounds" if ($START_ID < 1 or $START_ID > $datasize);
die "end id out of bounds" if ($END_ID < 1 or $END_ID > $datasize);
die "end id must be bigger than start" if ($END_ID < $START_ID);


## print CSV header 
print "id, gold, P_coll(h), P_model(h), P_coll(t), P_model(t), P_model(h|t), PMI(h;t), PPL(t), PPL(h), PPL(h|t), PPLgain,";
print "\n"; 
## 

# now select one
for (my $pair_id = $START_ID; $pair_id <= $END_ID; $pair_id++)
{
    my $id = $pair_id - 1; # id actually is starting from 0.

    my $text = call_splitta($t_aref->[$id]);
    my $hypo = call_splitta($h_aref->[$id]);

    print STDERR "Processing id $pair_id;\n";
    warn "SPLITTA failed! ==> fallback to lc(string).\n" unless($text and $hypo); 
    $text = lc($t_aref->[$id]) unless($text); 
    $hypo = lc($h_aref->[$id]) unless($hypo); 

    # patch for bad input "[" or "]". (e.g. 90th instance of test) 
    $text =~ s/\[|\]//g; 
    $hypo =~ s/\[|\]//g; 

    print STDERR "text: $text\n"; 
    print STDERR "hypo: $hypo\n"; 
    my ($collection_p_h, $model_p_h, $model_p_h_given_t, $h_words, $h_sents, $collection_p_t, $model_p_t, $t_words, $t_sents) = condprob_h_given_t($hypo, $text, $lambda, "./models/collection/collection.model", "./models/document", $RUN_ID);

    ## VALUE print 
    # prepare values to print. 
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
    print "$pair_id, $gold_aref->[$id], $out_p_coll_h, $out_p_model_h, $out_p_coll_t, $out_p_model_t, $out_p_model_h_given_t, $out_pmi_h_t, $t_ppl, $h_ppl, $h_given_t_ppl, $ppl_gain,"; 
    print "\n"; 
    ## 
}

sub MSRPC_reader
{
    # skip the first line 
    my $file = $_[0]; 
    open FILE, "<", $file or die "unable to read $file"; 
    my $line = <FILE>; 
    

    my @gold; 
    my @first_sent; 
    my @second_sent; 

    while($line = <FILE>)
    {
         #print $line; 
         my @items = split /\t/, $line; 
         my ($g, $sent1, $sent2); 
         foreach (@items)
         {
             #print "$_\n"; 
             $g = $items[0]; 
             $sent1 = $items[3]; 
             $sent2 = $items[4]; 
         }
         #print $gold, "\t", $first_sent, "\t", $second_sent, "\n"; 
         push @gold, $g; 
         push @first_sent, $sent1; 
         push @second_sent, $sent2;          
    }
    die "Eh, need to be called within an array context" unless defined wantarray; 
    return (\@gold, \@first_sent, \@second_sent); 
}
