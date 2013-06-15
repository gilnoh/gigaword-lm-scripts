# this simple script gets one data file (RTE5 like EXCI format), and 
# run P_h_t() over that problem, and outputs the result as a CSV file. 

use warnings; 
use strict; 
use POSIX qw(_exit); 
use Benchmark qw(:all); 
use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file $SOLR_URL); 

# internal config  
my $TEMP_DIR = "./temp"; # for splitta sentence splitter. 

# PARAMETERS to set (for proto_condprob.pm) 
our $DEBUG=0; # well, turn it on for quality check. 
set_num_thread(1);  
our $SOLR_URL = "http://localhost:9911/solr"; 
our $APPROXIMATE_WITH_TOP_N_HITS=4000; 

die "Usage: needs three arguments.\n\">perl loop_runner.pl [xml_rte5+_file] [start] [end]\n" unless ($ARGV[2]); 

my $target_file = $ARGV[0]; 
my $start = $ARGV[1]; 
my $end = $ARGV[2]; 

unless (-r $target_file)
{
    die "unable to open $target_file\n"; 
}

# begin, end sanity check? hmm. 

my $t0 = Benchmark->new; 

# read data 
my ($t_aref, $h_aref, $d_aref) = read_rte_data($target_file); 

for(my $id = $start; $id < $end +1; $id ++)
{
    run_one_case($id); 
}

my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 

#for(my $i=0; $i < scalar(@$t_aref); $i++)
#{
#    print "id: ", ($i+1), "\t", $d_aref->[$i] ,"\n"; 
#    print "T: ", $t_aref->[$i]; 
#    print "H: ", $h_aref->[$i]; 
#}

# # now select one 
# my $id = $ARGV[0] - 1; 
# die "something wrong with id: $id\n" unless ($id >= 0); 

sub run_one_case
{

# time in 
    my $t0 = Benchmark->new; 
    my $id = $_[0]; 

    my $text = call_splitta($t_aref->[$id-1]); 
    my $hypo = call_splitta($h_aref->[$id-1]); 

    my ($bb, $pmi, $P_pw_h_given_t, $P_h_given_t_minus_h, $tlen, $hlen, $P_h_given_t, $P_t, $P_h, $weighted_href) = P_h_t_index($hypo, $text, 0.5, "./models/collection/collection.model", "./models/document");

    print "$id|GOLD:$d_aref->[$id-1]|, $bb, $pmi, $P_pw_h_given_t, $P_h_given_t_minus_h, $tlen, $hlen, $P_h_given_t, $P_t, $P_h,\n";  

    my $t1 = Benchmark->new; 
    my $td = timediff($t1, $t0); 
    print STDERR "the code took:", timestr($td), "\n"; 
}
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
