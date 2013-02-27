# a perl module that uses srilm_call.pm & octave_call.pm 
# to calculate "common sense" as "conditional probability on LM over documents" 

package proto_condprob; 

use warnings; 
use strict; 
use Exporter; 
use srilm_call qw(read_debug3_p call_ngram); 
use octave_call;
use threads; 
use Carp; 

our @ISA = qw(Exporter); 
our @EXPORT = qw(P_t P_t_multithread P_h_t_multithread); 
our @EXPORT_OK = qw (set_num_thread P_coll P_doc $COLLECTION_MODEL $DEBUG); 

# some globals 
our $COLLECTION_MODEL = "./models/collection/collection.model"; 
#our $DOCUMENT_MODELS = "./models/document/afp_eng_2009/*.model"; 
our $DOCUMENT_MODELS_DIR = "./models/document"; 
our $LAMBDA = 0.5; 
our $NUM_THREAD = 4; 
our $DEBUG=2;  
# DEBUG level 
# 0: no addtional file output 
# 1: P_t_h_multithread will output intermediate result hash as files 
# 2: the hash output will be sorted (higher value first)      

my @collection_seq =(); # global variable that is filled by P_coll, and used by P_doc (thus in P_t)

sub set_num_thread
{
    $NUM_THREAD = $_[0]; 
}

sub P_h_t_multithread($$;$$$)
{
    # argument: hypothesis, text, lambda, collection model path, document models
    # output (return): 
    # ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ). 

    # argument check 
    my @args = @_; 
    my $hypothesis = shift @args; 
    my $text = shift @args; 
    die unless ($hypothesis and $text); 

    # calculate P(t) for each document model 
    print STDERR $text, "\n"; 
    my %text_per_doc = P_t_multithread($text, @args); # remaining @args will be checked there 
    # calculate P(t) overall 
    my @t = values %text_per_doc; 
    my $P_t = mean(\@t); # (on uniform P(d) )
    print STDERR "P(t) is $P_t \n"; 
    # dcode 
    export_hash_to_file(\%text_per_doc, "Pt_per_doc.txt"); 
    
    # calculate P(h) for each model 
    print STDERR $hypothesis, "\n"; 
    my %hypo_per_doc = P_t_multithread($hypothesis, @args); 
    # calculate P(h) overall 
    my @h = values %hypo_per_doc; 
    my $P_h = mean(\@h); # (on uniform P(d) ) 
    print STDERR "P(h) is (logprob): $P_h \n"; 
    # dcode
    export_hash_to_file(\%hypo_per_doc, "Ph_per_doc.txt"); 

    # calculate P(h|t,d) for each model 
    # note this %weighted is *non-normalized weight* (for evidence) 
    # and not the final prob. 
    my %weighted; 
    {
	foreach (keys %text_per_doc)
	{
	    $weighted{$_} = $text_per_doc{$_} + $hypo_per_doc{$_}; 
	}
    }
    # dcode
    export_hash_to_file(\%weighted, "PtPh_per_doc.txt"); 
    
    # calculate P(h|t) overall (that is, P(h|t,d)) 
    my $P_h_given_t = weighted_sum(\@t, \@h); 
    print STDERR "P(h|t) is (logprob):  $P_h_given_t \n"; 

    # calculate P(h|t) / P(h), as supporting measure. 
    my $gain = 10 ** ($P_h_given_t - $P_h); # note that this is not logprob
    print STDERR "P(h|t) / P(h) is (nonlog): ", $gain, "\n"; 

    # ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ). 
    return ($gain, $P_h_given_t, $P_h, $P_t, {%weighted}); 
}

sub P_t_multithread($;$$$) 
{
    # argument: text, lambda, collection model path, document model glob 
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
    if ($_[3]) { # document model path 
	$DOCUMENT_MODELS_DIR = $_[3]; 
    }

    my @subdir = get_subdirs($DOCUMENT_MODELS_DIR); 
    print STDERR "$DOCUMENT_MODELS_DIR has ", scalar (@subdir), " dirs (subdirs + itself) to follow;\n";

    my @document_model; 
    foreach my $d (@subdir)
    {
	print STDERR "$d: "; 
	my @ls = glob($d . "/*.model"); 
	print STDERR scalar(@ls), " model files\n"; 
	push @document_model, @ls; 
    }

    die "unable to find document models at $DOCUMENT_MODELS_DIR" unless (scalar @document_model); 

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
    # argument: $text, $lambda, $collection_model_file, $document_model_dir
    # out: a hash where a key is model name, and the associated 
    #      value is the value of P_model($text) 

    ## OLD parameters, they were...
    # argument: text, lambda, collection model path, document model glob 
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
	$DOCUMENT_MODELS_DIR = $_[3]; 
    }

    # get list of all document models     
    my @subdir = get_subdirs($DOCUMENT_MODELS_DIR); 
    print STDERR "$DOCUMENT_MODELS_DIR has ", scalar (@subdir), " dirs (subdirs + itself) to follow;\n";

    my @document_model; 
    foreach my $d (@subdir)
    {
	print STDERR "$d: "; 
	my @ls = glob($d . "/*.model"); 
	print STDERR scalar(@ls), " model files\n"; 
	push @document_model, @ls; 
    }

    die "unable to find document models at $DOCUMENT_MODELS_DIR" unless (scalar @document_model); 

    # call P_coll() 
    print STDERR "Calculating collection model logprob (to be interpolated)";  
    my @r = P_coll($text); # return value already saved in global @collection_seq
    my $coll_logprob = lambda_sum2(1, \@r, \@r); 
    print STDERR $coll_logprob, "\n"; 

    # for each model, call P_doc()     
    print STDERR "Calculating per-document model logprobs on, ", scalar(@document_model), " files\n"; 
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
    
    die "Calling P_doc requires previos call of P_coll" unless (scalar @collection_seq); 
    die "Unable to open path $_[0]" unless (-r $_[0]); 

    my @doc_seq = read_debug3_p(call_ngram($_[0])); 
    #print "\n", (scalar @doc_seq), "\t", (scalar @collection_seq), "\n"; 
    my $logprob = lambda_sum2($LAMBDA, \@doc_seq, \@collection_seq); 
    return $logprob; 
}


# a utility function 
sub export_hash_to_file
{
    return unless ($DEBUG); 
    my %h = %{$_[0]}; 
    my $filename = $_[1]; 
    open FILE, ">", $filename; 

    if ($DEBUG == 1 )
    {
	foreach (sort keys %h)
	{
	    print FILE "$_ \t $h{$_}\n"; 
	}
    }
    else #elsif ($DEBUG == 2)
    {
	foreach (sort {$h{$b} <=> $h{$a}} keys %h)
	{
	    print FILE "$_ \t $h{$_}\n"; 
	}
    }
    close FILE;
}


sub get_subdirs($)
{
# get_subdir("./somepath") will return all its subdirs, including itself. 
    my $toppath = $_[0]; 
    opendir (my $dh, $toppath) or croak "can't open dir $_[0]"; 
    my @subdir; # will hold all subdirectories of the given path 
    foreach (readdir($dh))
    {
	next if ( ($_ eq "..") ); 
	my $path = $toppath . "/" . $_; 
	push @subdir, $path if (-d $path); 
	
    }
    close $dh; 
    return @subdir; 
}


1; 
