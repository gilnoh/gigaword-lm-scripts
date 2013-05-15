# this simple script sketches how to call P(h|t) from 
# the RTE3 data. 

use warnings; 
use strict; 

use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file); 

our $DEBUG=0;
set_num_thread(4);  
our $APPROXIMATE_WITH_TOP_N_HITS=4000; 

# simple test 
my ($t_aref, $h_aref, $d_aref) = read_rte_data("./testdata/English_dev.xml"); 
for(my $i=0; $i < scalar(@$t_aref); $i++)
{
    print "id: ", ($i+1), "\t", $d_aref->[$i] ,"\n"; 
    print "T: ", $t_aref->[$i]; 
    print "H: ", $h_aref->[$i]; 

    my $text = call_splitta($t_aref->[$i]); 
    my $hypo = call_splitta($h_aref->[$i]); 

    my ($gain, $P_h_given_t, $P_h, $P_t, $weighted_href) = P_h_t_multithread_index($hypo, $text, 0.5, "./models/collection/collection.model", "./models/document", "./models_index");

    print "###", ($i+1), ", $gain, $P_h_given_t, $P_h, $P_t, ", length($hypo), ", ", length($text), "\n";  
    die if ($i > 3); 
}


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
