# a set of perl method that will rely on calculating 
# some log-probability calculations.  

package octave_call; 

use strict; 
use warnings; 
use Exporter;
our @ISA = qw(Exporter); 
our @EXPORT = qw(lambda_sum2 lambda_sum weighted_sum mean); 

my $OCTAVE_COMMAND="octave -q "; 
my $OCTAVE_EVAL_OPTION = "--eval "; 
my $WEIGHTED_SUM_FUNCTION = "weighted_sum"; 
#my $WEIGHTED_SUM_FUNCTION = "reference_weightedsum";  # Even faster, but inaccurate with low values :-( 
our $IGNORE_END_S = 1; 

my $MATFILE = "matrix4_weightedsum.csv"; 

sub weighted_sum
{
#    return weighted_sum_octave(@_); 
#    return weighted_sum_native(@_); 
    return weighted_sum_native2(@_); 
}

# all calculation will call the corresponding octave code...  
sub weighted_sum_octave($$) 
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
    #my $command = $OCTAVE_COMMAND . $OCTAVE_EVAL_OPTION . '"' . $l_line . $a_line . $b_line . $call_line . '"';  
    my $command = $OCTAVE_COMMAND . $OCTAVE_EVAL_OPTION . '"' . $call_line . '"';  

    #print STDERR $command, "\n"; 
    my $ans = `$command`; 
    #print STDERR $ans, "\n"; 
    $ans =~ /ans = (.+)$/; 

    # delte the file 
    return $1; 
}

sub weighted_sum_native
{
    # weighted_sum(\@doc_logprob, \@seq_logprob) 
    # gets two (same-size) array of log prob.
    # @doc_loprob, @sequence_log_prob. 
    # NOTE: both input and output are *log* probabilities. 
    my $doc_logprob_aref = $_[0]; 
    my $seq_logprob_aref = $_[1]; 
    
    my $result = 0; 
    my $col1_sum = 0; 
 
    for (my $i=0; $i < scalar (@{$doc_logprob_aref}); $i++)
    {
	my $doc_logprob = $doc_logprob_aref->[$i]; 
	my $seq_logprob = $seq_logprob_aref->[$i]; 
	my $this_log_prob = $doc_logprob + $seq_logprob; 
	
	if ($result == 0)
	{
	    $result = $this_log_prob; 
	}
	else
	{
	    $result = logprob_sum($result, $this_log_prob); 
	}

	if ($col1_sum == 0)
	{
	    $col1_sum = $doc_logprob; 
	}
	{
	    $col1_sum = logprob_sum($col1_sum, $doc_logprob); 
	}
    }
    my $weighted_sum = $result - $col1_sum; 
    return $weighted_sum;  
}


sub weighted_sum_native2
{
    # weighted_sum(\@doc_logprob, \@seq_logprob) 

    # DIFF:
    # why 2?: slightly faster version for specific cases: 
    # if there is tons of "min_value" filled items, this code is 
    # far faster than others. 
    # (see main pm code for more description about min-value fill: 
    # "fill in the prob of "no-hit" document models". ) 

    # WHAT it does: 
    # Gets two (same-size) array of log prob.
    # @doc_loprob, @sequence_log_prob. 
    # NOTE: both input and output are *log* probabilities. 


    # get min on both. 
    my $doc_logprob_aref = $_[0]; 
    my $seq_logprob_aref = $_[1]; 
    
    my $doc_min=0; 
    my $seq_min=0; 
    foreach (@$doc_logprob_aref)	
    {
	$doc_min = $_ if ($_ < $doc_min ) 
    }
    foreach (@$seq_logprob_aref)
    {
	$seq_min = $_ if ($_ < $seq_min )
    }
    die "weighted_sum_native2: sanity check failure\n" if ($doc_min == 0 or $seq_min ==0);  # sanity check 

    my $min_log_prob = $doc_min + $seq_min; 

    
    # main loop 
    my $result = 0; 
    my $col1_sum = 0; 
 
    my $num_min_min_case = 0; # number of cases where doc_logprob == doc_min 
                              # and seq_logprob == seq_min. 

    for (my $i=0; $i < scalar (@{$doc_logprob_aref}); $i++)
    {
	my $doc_logprob = $doc_logprob_aref->[$i]; 
	my $seq_logprob = $seq_logprob_aref->[$i]; 
	my $this_log_prob = $doc_logprob + $seq_logprob; 

	if (($doc_logprob == $doc_min) and ($seq_logprob == $seq_min))
	{
	    $num_min_min_case++; 
	    next; 
	}
	
	if ($result == 0)
	{
	    $result = $this_log_prob; 
	}
	else
	{
	    $result = logprob_sum($result, $this_log_prob); 
	}

	if ($col1_sum == 0)
	{
	    $col1_sum = $doc_logprob; 
	}
	{
	    $col1_sum = logprob_sum($col1_sum, $doc_logprob); 
	}
    }

    # okay. Now we have to add 
    # a) num_min_min_case (times) min_log_prob 
    #    to result, 
    # b) num_min_min_case (times) doc_min
    #    to col1_sum, 

    # case a) 
    my $val_a = log10($num_min_min_case) + $min_log_prob; 
    $result = logprob_sum($result, $val_a); 

    # case b)
    my $val_b = log10($num_min_min_case) + $doc_min; 
    $col1_sum = logprob_sum($col1_sum, $val_b); 
 
    # now we have result and col1_sum. divide. (in log) 
    my $weighted_sum = $result - $col1_sum; 
    return $weighted_sum;  
}


# base 10, sum of log probability 
sub logprob_sum
{
    my $a = $_[0]; 
    my $b = $_[1]; 
    
    my $m; 
    if ($a > $b)
    {
	$m = $a; 
    }
    else
    {
	$m = $b; 
    }

    my $logprob = log10 ( 10 ** ($a - $m) + 10 ** ($b - $m) ) + $m; 
    return $logprob; 
}

sub mean($) 
{
    # gets one list of log probabilities and outputs its 
    # mean, also as a log probability. 
    # simply calls weighted_sum with uniform weights 
    my $aref = $_[0]; 
    my $len = scalar (@$aref); 
    my @weight = (-1) x $len; 
    return weighted_sum(\@weight, $aref); 
}

sub log10 {
    my $n = shift;
    return log($n)/log(10);
}

sub lambda_sum2($$$)
{
    # a function that does lambda-sum, for linear interpolation 
    # of a ngram on word level 
    # E.g) labmda * P_a(w_n | w_n-1, w_n-2) + (1-lambda)* P_b(w_n | w_n-1, w_n-2) 

    # Input: lambda, and two *non-log* probabilities
    # Output: summed probability in *log probability* 

    # this function does everything in Perl, without calling external 
    # compare the result with lambda_sum_ref, which uses octave to do so. 

    my $lambda = $_[0]; 
    my $left_aref = $_[1]; # probability of P_doc, on each token
    my $right_aref = $_[2]; # probability of P_coll, on each token

    # sanity check 
    die unless ($lambda >= 0 and $lambda <=1); 
    die unless (scalar (@$left_aref) == scalar (@$right_aref)); 

    my @plist; 
    # calculation 
    for (my $i=0; $i < scalar (@$left_aref); $i++)
    {
	# if both of them are 0, this pair, will be ignored. 
	next if (($left_aref->[$i] == 0) and ($right_aref->[$i] ==0)); 

	my $val = (($left_aref->[$i] * $lambda) + ($right_aref->[$i] * (1 - $lambda))); 
	push @plist, log10($val); 
    }

    #(removing last <\s> if specified) 
    if ($IGNORE_END_S)
    {
    	pop @plist; 
    	die unless (scalar @plist); 
    }

    my $result = 0; 
    $result += $_ foreach (@plist);
    return $result; 
}

sub lambda_sum($$$)
{
    # ( a specific function for SRILM -debug output.) 
    # gets lambda, two list of (non-log) probability 
    # (same length, each per token) 
    # returns one *log* probability, summed with lambda and then 
    # producted (log-summed) to make single probability. 
    # NOTE: *non-log* prob list in, *log* prob out. 
   
    my $lambda = $_[0]; 
    my $left_aref = $_[1]; # probability of P_doc, on each token
    my $right_aref = $_[2]; # probability of P_coll, on each token
    
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

    # (removing last <\s> if specified) 
    if ($IGNORE_END_S)
    {
    	pop @left;
    	pop @right; 
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
