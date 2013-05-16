# this simple script gets an id number and runs  
# P_h_t() over that problem. 

use warnings; 
use strict; 
use POSIX qw(_exit); 
use Benchmark qw(:all); 
use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file); 

my $DEVFILE = "./testdata/English_dev.xml"; 

die "Usage: needs one number argument.\n>perl runner.pl 3 will pick problem id 3 and run it." unless ($ARGV[0]); 

# PARAMETERS to set (for proto_condprob.pm) 
our $DEBUG=0;
set_num_thread(4);  
our $APPROXIMATE_WITH_TOP_N_HITS=4000; 

# time in 
my $t0 = Benchmark->new; 

# read data 
my ($t_aref, $h_aref, $d_aref) = read_rte_data($DEVFILE); 
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

my ($gain, $P_h_given_t, $P_h, $P_t, $weighted_href) = P_h_t_multithread_index($hypo, $text, 0.5, "./models/collection/collection.model", "./models/document", "./models_index");

$| = 1; 
print "$ARGV[0]|GOLD:$d_aref->[$id]|, $gain, $P_h_given_t, $P_h, $P_t, ", length($hypo), ", ", length($text), "\n";  

#_exit(0); 
# time out
my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
print STDERR "the code took:", timestr($td), "\n"; 
_exit(0); 
###
###
###

# call splitta for tokenization ... 
sub call_splitta 
{
    # TODO actually call splitta 

    my $s = shift; 
    $s =~ s/.$//; 
    return lc($s); 
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
