# a set of perl method that will rely on calculating 
# some log-probability calculations.  

require Exporter;
@ISA = qw(Exporter); 
@EXPORT = qw(lambda_sum); 

my $OCTAVE_COMMAND="octave -q "; 
my $OCTAVE_EVAL_OPTION = "--eval "; 

# all calculation will call the corresponding octave code...  

sub lambda_sum($@@)
{
    # gets lambda, two list of log probability 
    # (same length, each per token) 
   
    my $lambda = $_[0]; 
    my $left_aref = $_[1]; # log probability of P_doc, on each token
    my $right_aref = $_[2]; # log probability of P_coll, on each token
    
    # sanity check 
    die unless ($lambda > 0 and $lambda <1); 
    die unless (scalar (@$left_aref) == scalar (@$right_aref)); 

    # remove "both 0" element" 
    my @left;
    my @right; 
    for (my $i=0; $i < scalar (@$left_aref); $i++)
    {
	# if both of them are 0, this pair, will be ignored. 
	next if (($left_aref->[$i] == 0) and ($right_aref->[$i] ==0)); 
	push @left, $left_aref->[$i]; 
	push @right, $right_aref ->[$i]; 
    }

    # prepare command and run octave 

    my $l_line = "l = $lambda; "; 
    my $a_line = "a = ["; 
    foreach (@left)
    {
	$a_line .= "$_ "; 
    }
    $a_line .="]; "; 

    my $b_line = "b = ["; 
    foreach (@right)
    {
	$b_line .= "$_ "; 
    }
    $b_line .="]; "; 

    my $call_line = "lambda_sum(l,a,b)"; 
    my $command = $OCTAVE_COMMAND . $OCTAVE_EVAL_OPTION . '"' . $l_line . $a_line . $b_line . $call_line . '"';  

    print STDERR $command, "\n"; 
    my $ans = `$command`; 
    $ans =~ /ans = (.+)$/; 
    return $1; 
}
1; 
