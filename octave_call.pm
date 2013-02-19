# a set of perl method that will rely on calculating 
# some log-probability calculations.  

require Exporter;
@ISA = qw(Exporter); 
@EXPORT = qw(lambda_sum weighted_sum mean); 

my $OCTAVE_COMMAND="octave -q "; 
my $OCTAVE_EVAL_OPTION = "--eval "; 
my $WEIGHTED_SUM_FUNCTION = "weighted_sum"; 

my $MATFILE = "matrix4_weightedsum.csv"; 

# all calculation will call the corresponding octave code...  
sub weighted_sum(@@) 
{
    # weighted_sum(\@doc_logprob, \@seq_logprob) 
    # gets two (same-size) array of log prob.
    # @doc_loprob, @sequence_log_prob. 
    # Calls octave to do the weighted sum in logarithm. 
    # NOTE: both input and output are *log* probabilities. 
    
    my @doc_logprob = @{$_[0]};
    my @seq_logprob = @{$_[1]}; 
    die unless (scalar (@doc_logprob) == scalar (@seq_logprob)); 

    # write matrix that can be loaded in Octve by 
    # load ("file", "options", "variablename") 
    open FILE, ">", $MATFILE; #"matrix_4_weighted_sum.csv"; 
    for (my $i=0; $i < @doc_logprob; $i++)
    {
	print FILE "$doc_logprob[$i],$seq_logprob[$i]\n"; 
    }
    close FILE; 

    # run Octave, load that data and call function 
    #my $call_line = "X = csvread(\'$MATFILE\'); weighted_sum(X)"; 
    my $call_line = "X = csvread(\'$MATFILE\'); " . $WEIGHTED_SUM_FUNCTION ."(X)"; 
    my $command = $OCTAVE_COMMAND . $OCTAVE_EVAL_OPTION . '"' . $l_line . $a_line . $b_line . $call_line . '"';  

    #print STDERR $command, "\n"; 
    my $ans = `$command`; 
    #print STDERR $ans, "\n"; 
    $ans =~ /ans = (.+)$/; 

    # delte the file 
    return $1; 
}

sub mean(@) 
{
    # gets one list of log probabilities and outputs its 
    # mean, also as a log probability. 
    # simply calls weighted_sum with uniform weights 
    my $aref = $_[0]; 
    my $len = scalar (@$aref); 
    my @weight = (-1) x $len; 
    return weighted_sum(\@weight, $aref); 
}


sub lambda_sum($@@)
{
    # ( a specific function for SRILM -debug output.) 
    # gets lambda, two list of (non-log) probability 
    # (same length, each per token) 
    # returns one *log* probability, summed with lambda and then 
    # producted (log-summed) to make single probability. 
    # NOTE: *non-log* prob list in, *log* prob out. 
   
    my $lambda = $_[0]; 
    my $left_aref = $_[1]; # log probability of P_doc, on each token
    my $right_aref = $_[2]; # log probability of P_coll, on each token
    
    # sanity check 
    die unless ($lambda >= 0 and $lambda <=1); 
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

    #print STDERR $command, "\n"; 
    my $ans = `$command`; 
    #print STDERR $ans, "\n"; 
    $ans =~ /ans = (.+)$/; 
    return $1; 
}

1; 
