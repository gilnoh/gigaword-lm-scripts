# simple script that updates two caches for the given RTE3 file. 
# this enables faster + multi-instance access on the data. 

use warnings; 
use strict; 

use Benchmark qw(:all);
use condprob qw(:DEFAULT set_num_thread $DEBUG export_hash_to_file $SOLR_URL P_coll $USE_CACHE_ON_SPLITTA $USE_CACHE_ON_COLL_MODEL); 

my $TEMP_DIR = "./temp";
our $USE_CACHE_ON_SPLITTA = 1; 
our $USE_CACHE_ON_COLL_MODEL = 1; 

die "Usage: needs three arguments.\n\">perl cache_runner.pl msr_pp_filename start_num end_num \"\n perl runner.pl ./testdata/msr_paraphrase_test.txt 1 1725 \n" unless ($ARGV[2]);

my $inputfile = $ARGV[0];
die "unable to open file: $inputfile" unless (-r $inputfile);

my $START_ID = $ARGV[1] + 0;
my $END_ID = $ARGV[2] + 0;
my $RUN_ID = "cacherun"; # this cache_runner isn't supposed to run multiple instances. 

# read data 
my ($gold_aref, $t_aref, $h_aref) = MSRPC_reader($inputfile); 

my $datasize = scalar (@{$gold_aref}); 

die "start id out of bounds" if ($START_ID < 1 or $START_ID > $datasize);
die "end id out of bounds" if ($END_ID < 1 or $END_ID > $datasize);
die "end id must be bigger than start" if ($END_ID < $START_ID);

our $DEBUG=0; # well, turn it on for quality check. 

# time in 
my $t0 = Benchmark->new;

for (my $pair_id = $START_ID; $pair_id <= $END_ID; $pair_id++)
{
    print STDERR "Working on Pair $pair_id. \na) filling tokenization cache\n"; 
    my $id = $pair_id - 1; 
    print STDERR "\t.";
    my $text = call_splitta($t_aref->[$id]);
    print STDERR "\t."; 
    my $hypo = call_splitta($h_aref->[$id]);

    warn "SPLITTA failed! ==> fallback to lc(string).\n" unless($text and $hypo); 
    $text = lc($t_aref->[$id]) unless($text); 
    $hypo = lc($h_aref->[$id]) unless($hypo); 

    # (MSR_PP only) 
    # patch for bad input "[" or "]". (e.g. 90th instance of test) 
    $text =~ s/\[|\]//g; 
    $hypo =~ s/\[|\]//g; 

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


