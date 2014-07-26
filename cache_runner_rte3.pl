# simple script that updates two caches for the given RTE3 file. 
# this enables faster + multi-instance access on the data. 

use warnings; 
use strict; 

use Benchmark qw(:all);
use condprob qw(:DEFAULT set_num_thread $DEBUG export_hash_to_file $SOLR_URL P_coll $USE_CACHE_ON_SPLITTA $USE_CACHE_ON_COLL_MODEL); 

my $TEMP_DIR = "./temp";
our $USE_CACHE_ON_SPLITTA = 1; 
our $USE_CACHE_ON_COLL_MODEL = 1; 

die "Usage: needs three arguments.\n\">perl cache_runner.pl rte_filename start_num end_num \"\n perl runner.pl ./testdata/English_dev.xml 1 800 \n" unless ($ARGV[2]);

my $RTEFILE = $ARGV[0];
die "unable to open file: $RTEFILE" unless (-r $RTEFILE);

my $START_ID = $ARGV[1] + 0;
my $END_ID = $ARGV[2] + 0;
my $RUN_ID = "cacherun"; # this cache_runner isn't supposed to run multiple instances. 

die "start id out of bounds" if ($START_ID < 1 or $START_ID > 800);
die "end id out of bounds" if ($END_ID < 1 or $END_ID > 800);
die "end id must be bigger than start" if ($END_ID < $START_ID);

our $DEBUG=0; # well, turn it on for quality check. 

# time in 
my $t0 = Benchmark->new;

# read data 
my ($t_aref, $h_aref, $d_aref) = read_rte_data($RTEFILE);

for (my $pair_id = $START_ID; $pair_id <= $END_ID; $pair_id++)
{
    print STDERR "Working on Pair $pair_id. \na) filling tokenization cache\n"; 
    my $id = $pair_id - 1; 
    print STDERR "\t.";
    my $text = call_splitta($t_aref->[$id], "cache_run_rte3");
    print STDERR "\t."; 
    my $hypo = call_splitta($h_aref->[$id], "cache_run_rte3");

    warn "SPLITTA failed! ==> fallback to lc(string).\n" unless($text and $hypo); 
    $text = lc($t_aref->[$id]) unless($text); 
    $hypo = lc($h_aref->[$id]) unless($hypo); 

#    print STDERR "\n"; 
#    print STDERR "text: $text\n"; 
#    print STDERR "hypo: $hypo\n"; 

    print STDERR "b) filling collection model cache\n"; 
    print STDERR "\t."; 
    my @r_t = P_coll($text); 
    print STDERR "\t."; 
    my @r_h = P_coll($hypo); 
    print STDERR "\n"; 
}


print STDERR "cache run ended\n";
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

