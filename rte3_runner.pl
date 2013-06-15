# this simple script gets an id number and runs  
# P_h_t() over that problem. 

use warnings; 
use strict; 
use POSIX qw(_exit); 
use Benchmark qw(:all); 
use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file $SOLR_URL); 

my $TRAINFILE = "./testdata/English_dev.xml"; 
my $TESTFILE = "./testdata/English_test.xml"; 
my $TEMP_DIR = "./temp"; 
die "Usage: needs two argument.\n\">perl runner.pl 3 train\" will pick train data  id 3 and run it. [train/test]" unless ($ARGV[1]); 

my $RTEFILE; 
if ((lc($ARGV[1]) eq "train")  or (lc($ARGV[1]) eq "dev") )
{
    $RTEFILE = $TRAINFILE; 
}
elsif((lc($ARGV[1]) eq "test"))
{
    $RTEFILE = $TESTFILE; 
}
else
{
    die "unknown ARGV[1]: $ARGV[1]\n"; 
}

# PARAMETERS to set (for proto_condprob.pm) 
our $DEBUG=0; # well, turn it on for quality check. 
set_num_thread(1);  
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
my $id = $ARGV[0] - 1; 
die "something wrong with id: $id\n" unless ($id >= 0); 

my $text = call_splitta($t_aref->[$id]); 
my $hypo = call_splitta($h_aref->[$id]); 

#my ($bb, $pmi, $P_pw_h_given_t, $P_h_given_t_minus_h, $tlen, $hlen, $P_h_given_t, $P_t, $P_h, $weighted_href) = P_h_t_multithread_index($hypo, $text, 0.5, "./models/collection/collection.model", "./models/document", "./models_index");

my ($bb, $pmi, $P_pw_h_given_t, $P_h_given_t_minus_h, $tlen, $hlen, $P_h_given_t, $P_t, $P_h, $weighted_href) = P_h_t_index($hypo, $text, 0.5, "./models/collection/collection.model", "./models/document");

#$| = 1; 
print "$ARGV[0]|GOLD:$d_aref->[$id]|, $bb, $pmi, $P_pw_h_given_t, $P_h_given_t_minus_h, $tlen, $hlen, $P_h_given_t, $P_t, $P_h,\n";  

# time stamp
my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
print STDERR "the code took:", timestr($td), "\n"; 
exit(0); 
###
###
###

# call splitta for tokenization ... 
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
	$splitted .= $_; 
    }
    close INFILE; 

    #$splitted =~ s/\n/ /g; # we will treat them as single big sentences 
    #$splitted =~ s/ , / /g; # ? and we ignoring commas? ,  
    $splitted =~ s/\.\n/\n/g; # remove end-of-line dots ... 

    return lc($splitted); 
}


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
