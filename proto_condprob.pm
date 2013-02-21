# a perl module that uses srilm_call.pm & octave_call.pm 
# to calculate "common sense" as "conditional probability on LM over documents" 

package proto_condprob; 

use warnings; 
use strict; 
use Exporter; 
use srilm_call qw(read_debug3_p call_ngram); 
use octave_call;
use threads; 

our @ISA = qw(Exporter); 
our @EXPORT = qw(P_t P_t_multithread); 
our @EXPORT_OK = qw (P_coll P_doc $COLLECTION_MODEL $DOCUMENT_MODEL_PATH); 

# some constants 
our $COLLECTION_MODEL = "./output/collection.model"; 
our $DOCUMENT_MODELS = "./output/afp_eng_2009/*.model"; 
our $LAMBDA = 0.5; 
our $NUM_THREAD = 6; 


my @collection_seq =(); # global variable that is filled by P_coll, and used by P_doc (thus in P_t)

sub P_t_multithread($;$$$) 
{
    # argument: text, lambda, collection model path, document model path 
    # out: a hash (model name, prob of given text produced from the model) 

    my %result; # $result{"model_id"} = log prob of $text from 'model_id' 

    # argument copy & sanity check 
    my $text = $_[0]; 
    die unless ($text); 
    if ($_[1]) { # lambda 
	die unless ($_[1] >=0 and $_[1] <= 1); 
	$LAMBDA = $_[1]; 
    }
    if ($_[2]) { # collection model (single file) 
	die unless (-r $_[2]);
	$COLLECTION_MODEL = $_[2]; 
    }
    if ($_[3]) { # document models as file glob string (e.g. "path/*.model") 
	$DOCUMENT_MODELS = $_[3]; 
    }

    # get list of all document models     
    my @document_model = glob($DOCUMENT_MODELS); 
    die unless (scalar @document_model); 

    # call P_coll() 
    print STDERR "Calculating collection model logprob (to be interpolated)";  
    my @r = P_coll($text); # return value already saved in global @collection_seq
    my $coll_logprob = lambda_sum2(1, \@r, \@r); 
    print STDERR $coll_logprob, "\n"; 

    # for each model, call P_doc()     
    print STDERR "Calculating per-document model logprobs, ", scalar(@document_model), " files\n"; 

    # # divide the input 
    # my @aref_array; 
    # {
    # 	my $n = int (scalar (@document_model) / $NUM_THREAD); 
    # 	my $start = 0; 
    # 	my $end = $n-1; 

    # 	for(my $i=0; $i < ($NUM_THREAD - 1); $i++) # until last part 
    # 	{
    # 	    my @a = @document_model[$start .. $end]; 
    # 	    $start += $n; 
    # 	    $end = $start + $n - 1; 
    # 	    push @aref_array, [@a];  
    # 	}   
    # 	# last part 
    # 	$end = (scalar @document_model) - 1;  
    # 	my @a = @document_model[$start .. $end]; 
    # 	push @aref_array, [@a]; 

    # 	#sanity check 
    # 	die unless ((scalar (@aref_array)) == $NUM_THREAD); 
    # 	my $sum =0; 
    # 	foreach (@aref_array)
    # 	{
    # 	    $sum += scalar @{$_}; 
    # 	}
    # 	die unless (scalar(@document_model) == $sum); 
    # }    
    
    # generate the threads, and run them with 1/number_thread array parts. 
    my @thread; 
    my $n = int (scalar (@document_model) / $NUM_THREAD); 
    my $start = 0; 
    my $end = $n-1; 

    for (my $i=0; $i < $NUM_THREAD; $i++)
    {
	# dcode
	# print STDERR "$start - $end\n"; 
	# () needed: array context. see http://perldoc.perl.org/threads.html#THREAD-CONTEXT
    	($thread[$i]) = threads->create(\&P_d_runner, @document_model[$start .. $end]);
    	# update start-end for the next array
    	$start += $n; 
    	$end = $start + $n - 1; 
    	$end = ((scalar @document_model) -1) if (($i+1) == $NUM_THREAD -1); # last part special case
    }
       
    # wait for threads to end. 
    my %parts; 
    for (my $i=0; $i < $NUM_THREAD; $i++)
    {
    	my %r = $thread[$i]->join(); 
    	#print $r[0], "\t", $r[1], "\n"; 
    	%parts = (%parts, %r); 
    }
    # sum up the results from the thread 
    
    %result = %parts; 
    
    #%result = P_d_runner(@document_model); 
    return %result; 
}

sub P_d_runner
{
    # internal helper sub that is used by P_t_multithread. 
    # gets a list of model files, call P_d on each of them. 
    my %r; 
    my $count = 0; 
    foreach (@_)
    {
	$r{$_} = P_doc($_); 
	print STDERR "." unless ($count++ % 100); 
    }
    return %r;
}


sub P_t($;$$$) 
{
    # argument: text, lambda, collection model path, document model path 
    # out: a hash (model name, prob of given text produced from the model) 

    my %result; # $result{"model_id"} = log prob of $text from 'model_id' 

    # argument copy & sanity check 
    my $text = $_[0]; 
    die unless ($text); 
    if ($_[1]) { # lambda 
	die unless ($_[1] >=0 and $_[1] <= 1); 
	$LAMBDA = $_[1]; 
    }
    if ($_[2]) { # collection model (single file) 
	die unless (-r $_[2]);
	$COLLECTION_MODEL = $_[2]; 
    }
    if ($_[3]) { # document models as file glob string (e.g. "path/*.model") 
	$DOCUMENT_MODELS = $_[3]; 
    }

    # get list of all document models     
    my @document_model = glob($DOCUMENT_MODELS); 
    die unless (scalar @document_model); 

    # call P_coll() 
    print STDERR "Calculating collection model logprob (to be interpolated)";  
    my @r = P_coll($text); # return value already saved in global @collection_seq
    my $coll_logprob = lambda_sum2(1, \@r, \@r); 
    print STDERR $coll_logprob, "\n"; 

    # for each model, call P_doc()     
    print STDERR "Calculating per-document model logprobs, ", scalar(@document_model), " files\n"; 
    my $count = 0; 
    foreach (@document_model)
    {
    	my $logprob = P_doc($_); 
    	$result{$_} = $logprob; 
	
    	print STDERR "." unless ($count++ % 100); 
    }
    
    print STDERR  "\n"; 
    return %result; 
}



# internal function that records collection probability per words 
# (model to be interpolated for each P_doc model) 
sub P_coll($)
{
    # sanity check 
    die "unable to find collection model file $COLLECTION_MODEL\n" unless (-r $COLLECTION_MODEL); 
    my $sent = $_[0]; 

    # from srilm_call.pm 
    my @out = call_ngram($COLLECTION_MODEL, "", $sent); 
    @collection_seq = read_debug3_p(@out); 

    return @collection_seq; 
}

# internal function, that assumes previous call on P_coll  
sub P_doc($) 
{
    # arg[0]: document model path 
    
    die unless (scalar @collection_seq); 
    die unless (-r $_[0]); 

    my @doc_seq = read_debug3_p(call_ngram($_[0])); 
    #print "\n", (scalar @doc_seq), "\t", (scalar @collection_seq), "\n"; 
    my $logprob = lambda_sum2($LAMBDA, \@doc_seq, \@collection_seq); 
    return $logprob; 
}


1; 
