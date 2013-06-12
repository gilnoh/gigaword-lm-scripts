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

use WebService::Solr; 
use WebService::Solr::Document; 
use WebService::Solr::Query; 

# to be removed: plucene 
use Plucene; 
use Plucene::Document; 
use Plucene::Document::Field; 
use Plucene::Search::IndexSearcher; 
use Plucene::Analysis::SimpleAnalyzer; 
use Plucene::Analysis::Standard::StandardAnalyzer; 
use Plucene::Index::Writer; 
use Plucene::QueryParser; 

our @ISA = qw(Exporter); 
our @EXPORT = qw(P_t P_t_multithread P_h_t_multithread P_t_multithread_index P_h_t_multithread_index P_h_t_index P_t_index); 
our @EXPORT_OK = qw (set_num_thread P_coll P_doc solr_query get_path_from_docid plucene_query $COLLECTION_MODEL $DEBUG $DOCUMENT_INDEX_DIR $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file); 

# some globals 
# let's assume local host 
our $SOLR_URL = "http://localhost:9911/solr"; 
our $COLLECTION_MODEL = "./models/collection/collection.model"; 
#our $DOCUMENT_MODELS = "./models/document/afp_eng_2009/*.model"; 
our $DOCUMENT_MODELS_DIR = "./models/document"; 
our $DOCUMENT_INDEX_DIR = "./models_index"; 
our $LAMBDA = 0.5; 
our $NUM_THREAD = 4; 
our $APPROXIMATE_WITH_TOP_N_HITS = 1000; # if this is 0, all document models will be used in P_t_multithread_index. if this has a number, only those top N hits will be used as approximation of P_t. 

our $DEBUG=2;  
# DEBUG level 
# 0: no addtional file output 
# 1: P_t_h_multithread will output intermediate result hash as files 
# 2: the hash output will be sorted (higher value first)      

## GLOBALS 
my @collection_seq =(); # global variable that is filled by P_coll, and used by P_doc (thus in P_t)
## my $searcher; # an instance of Plucene::Search::IndexSearcher, we will keep only one copy when running. 
my @all_model =(); # global variable that is filled in P_h_t_multithread_index. This array keeps the full list of .model files for this run... 
my $all_model_top_path; # Associated value to @all_models. See P_h_t_multithread_index

sub set_num_thread
{
    $NUM_THREAD = $_[0]; 
}

sub P_h_t_multithread
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
    my @text;
    my @hypo; 
    {
	foreach (keys %text_per_doc)
	{
	    $weighted{$_} = $text_per_doc{$_} + $hypo_per_doc{$_}; 
	    push @text, $text_per_doc{$_}; 
	    push @hypo, $hypo_per_doc{$_}; 
	}
    }
    # dcode
    export_hash_to_file(\%weighted, "PtPh_per_doc.txt"); 
    
    # calculate P(h|t) overall (that is, P(h|t,d)) 
    # WARNING: we made sure in the previous step, @text and @hypo sorted on the same 
    # list of files. That means that $text[$n] and $hypo[$n] came from the same doc.
    # This must be guaranteeded! 
    my $P_h_given_t = weighted_sum(\@text, \@hypo); 
    print STDERR "P(h|t) is (logprob):  $P_h_given_t \n"; 

    # calculate P(h|t) / P(h), as supporting measure. 
    my $gain = ($P_h_given_t - $P_h); 
    print STDERR "P(h|t) / P(h) (PMI) is: ", $gain, "\n"; 

    # ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ). 
    return ($gain, $P_h_given_t, $P_h, $P_t, {%weighted}); 
}

sub P_t_multithread
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


sub P_t
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
sub P_coll
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
sub P_doc
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


sub get_subdirs
{
    # get_subdir("./somepath") will return all its subdirs, 
    # (up to depth 2), including top dir itself. 

    my $toppath = $_[0]; 
    opendir (my $dh, $toppath) or croak "can't open dir $_[0]"; 
    my @subdir; # will hold all subdirectories of the given path 
    foreach (readdir($dh))
    {
	next if ( ($_ eq "..") ); 
	my $path = $toppath . "/" . $_; 
	push @subdir, $path if (-d $path); 
	# push sub-sub dir, if any 
	if (-d $path)
	{
	    unless ($_ eq ".")
	    {
		opendir (my $dsubh, $path) or die "can't open dir $path\n"; 
		foreach (readdir($dsubh))
		{
		    next if ( ($_ eq "..") or ($_ eq ".")); 
		    push @subdir, ($path . "/" . $_); 
		}
		close $dsubh; 
	    }
	} # end sub-sub
    }
    close $dh; 
    return @subdir; 
}

# sole_query($text_str) 
# gets a (already tokenized) string, and query SOLR; 
# returns: my ($aref_doc_ids); 

sub solr_query
{
    my $query_str = $_[0]; 
    
    # prepare query terms 
    $query_str =~ s/\"//g; 
    $query_str =~ s/\'//g; # cases like "Amy's" can't happen, if it is properly tokenized. And all target documents are already tokenized. So. 
    # $query_str =~ s/ and //g; # for special relation terms for Plucene::SEARCH::QUERY. 
    # $query_str =~ s/ or //g; 
    # $query_str =~ s/ not //g; 
    # $query_str =~ s/ phrase //g; 
    $query_str =~ s/,//g; 
    $query_str =~ s/\n/ /g; 

    my @term_list = split(/\s+/, $query_str); 

    # prepare solr, and the query 
    my $solr = WebService::Solr->new($SOLR_URL);
    my $query = WebService::Solr::Query->new ( { -default => [@term_list] }); 
    my $query_options =  {rows => "$APPROXIMATE_WITH_TOP_N_HITS"}; # maximum number of returns 

    # sending query, if the port is not accessible, it will raise carp die
    my $response = $solr->search ( $query, $query_options ); 
    

    my @result_id; 
    for my $doc ( $response->docs ) {
	# the response docs are already sorted with relevancy. 
	push @result_id, $doc->value_for('id'); 
    }

    return \@result_id; 
}



# plucene_query($text_str) 
# : a query method that query on Plucene index $DOCUMENT_INDEX_DIR 
# and returns two references. 
# returns: my ($ref_array_doc_names, $ref_hash_perdoc_score, $total_doc_num) 
# $ref_array is an ordered array of document names. ("good hit first"). 

# DONNO why, but this code claims more and more memory each time it is being called. Prolly problem within PLUCENE. Dull old code.l Should drop it and replace it with SOLR server calling. 
sub plucene_query
{ 
    my $query_str = $_[0]; 

    # process the query sting, to remove any problem. 
    # remove any \" from query string 
    $query_str =~ s/\"//g; 
    $query_str =~ s/\'//g; # cases like "Amy's" can't happen, if it is properly tokenized. And all target documents are already tokenized. So. 
    $query_str =~ s/ and //g; # for special relation terms for Plucene::SEARCH::QUERY. 
    $query_str =~ s/ or //g; 
    $query_str =~ s/ not //g; 
    $query_str =~ s/ phrase //g; 
    $query_str =~ s/,//g; 
    $query_str =~ s/\n/ /g; 
      
    # prepare query
    my $parser = Plucene::QueryParser->new({
	analyzer => Plucene::Analysis::SimpleAnalyzer->new(),
	default  => "text" # Default field for non-specified queries
					   });
    my $query = $parser->parse($query_str); 

    # search 
    #unless ($searcher)
    #{
	print STDERR "Loading index - \n"; 
    my $searcher = Plucene::Search::IndexSearcher->new($DOCUMENT_INDEX_DIR);
    #}
    my $reader = $searcher->reader(); 
    my $total_doc = $reader->num_docs(); 
    print STDERR "The index has ", $total_doc, " documents\n"; 

    #my @docs; #TBR 
    my %docscore; 
    my $hc = Plucene::Search::HitCollector->new(collect => sub {
	my ($self, $id, $score) = @_;
	my $doc = $searcher->doc($id);
	#push @docs, $doc; #TBR
	my $docid = $doc->get("id")->string(); 

	# reduce docid 
	$docid =~ s/^$DOCUMENT_MODELS_DIR//; 
	$docid =~ s/\.story$//; 
	#print $docid, "\n"; 
	$docscore{$docid} = $score; # for score.
						});

    $searcher->search_hc($query => $hc);
    print STDERR "Hits collected - sorting by decending match score\n"; 
    my @sorted_docid; 
    foreach (sort {$docscore{$b} <=> $docscore{$a}} keys %docscore)
    {
	push @sorted_docid, $_; 
    }
    #undef $searcher; # any changes with this? (e.g. early GC?) No. 

    #return (\@sorted_docid, \%docscore, $total_doc); 
    return (\@sorted_docid, $total_doc); 
}


# P_t_multithread_index 
# same as P_t_multithread, but this will one additional argument index path
# and will return the same thing. 

sub P_t_multithread_index
{
    # argument: text, lambda, collection model path, document model glob, document index path 
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
	die unless (-e $_[3]); 
	$DOCUMENT_MODELS_DIR = $_[3]; 
    }
    if ($_[4]) { # plucene index path
	die unless (-e $_[4]); 
	$DOCUMENT_INDEX_DIR = $_[4]; 
    }
    #my ($hits_aref, $hits_href, $total_doc_size) = plucene_query($text); 
    my ($hits_aref, $total_doc_size) = plucene_query($text); 
    print STDERR "Search hits returned.\n"; 

    # sanity check 
    my $hit_size = scalar (@{$hits_aref}); 
    warn "$text resulted no hits in plucene index" unless ($hit_size); 

    # prepare list of models 
    my @document_model; 
    
    if ( $APPROXIMATE_WITH_TOP_N_HITS > 0 )
    { 	# use top N only. 
	my $n = 0; 
	foreach (@{$hits_aref}) # hits_aref is already sorted with search hit score, top first. 
	{
	    my $docid = $_; 
	    # restore the full path: it was reduced like this. 
	    #$docid =~ s/^$DOCUMENT_MODELS_DIR//; 
	    #$docid =~ s/\.story$//; 

	    $docid = $DOCUMENT_MODELS_DIR . $docid; 
	    $docid = $docid . ".story"; 

	    s/\/\.\//\//g;  # /./ -> / 
	    push @document_model, ($docid . ".model"); 
	    $n++; 
	    last if ($n >= $APPROXIMATE_WITH_TOP_N_HITS); 
	}
    }
    else 
    {   # use all of them. 
	foreach (@{$hits_aref}) 
	{
	    s/\/\.\//\//g;  # /./ -> / 
	    push @document_model, ($_ . ".model"); 
	}
    }
    
    undef $hits_aref; # memory clean? hmm. 

    # call P_coll() 
    print STDERR "Calculating collection model logprob (to be interpolated)";  
    my @r = P_coll($text); # return value already saved in global @collection_seq
    my $coll_logprob = lambda_sum2(1, \@r, \@r); 
    print STDERR $coll_logprob, "\n"; 

    # for each model, call P_doc()     
    print STDERR "Calculating per-document model logprobs for ", scalar(@document_model), " files (among $total_doc_size total doc) \n"; 

    # generate the threads, and run them with 1/number_thread array parts. 
    my @thread; 
    my $n = int ((scalar (@document_model)) / ($NUM_THREAD+0.0)); 
    my $start = 0; 
    my $end = $n-1; 

    for (my $i=0; $i < $NUM_THREAD; $i++)
    {
	# dcode
	#print STDERR "$start - $end\n"; 
	#print STDERR "$document_model[$start] - $document_model[$end]\n"; 

    	($thread[$i]) = threads->create(\&P_d_runner, @document_model[$start .. $end]); # () needed: array context. see http://perldoc.perl.org/threads.html#THREAD-CONTEXT

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

    # for debug code 
    my $max_prob = P_doc($document_model[0]); 
    my $cut_prob = 0; 
    #if ($APPROXIMATE_WITH_TOP_N_HITS < (scalar @document_model))
    if ((scalar @document_model) < $total_doc_size)
    {
	my $last = $APPROXIMATE_WITH_TOP_N_HITS -1; 
	$last = ($hit_size - 1) if ($last > ($hit_size - 1)); 
	$cut_prob = P_doc($document_model[$last]); 
    }

    # now, fill in the prob of "no-hit" document models 
    # first, calculate the minimum no-hit prob. 
    my %final_result; 
    my $min_prob; 
    {
	my @t; 
	push @t, 0 foreach (@r); 
	$min_prob = lambda_sum2($LAMBDA, \@t, \@r); 
    }

    # get all docmodel list 

    print STDERR "\nCalculating per-doc prob for hits done. Filling in min-prob for no-hits\n";     
    print STDERR "(min prob fillvalue is: $min_prob)\t (maxprob was: $max_prob)\t (cutpoint has: $cut_prob)\n"; 
    if ($max_prob < $cut_prob)
    {
	print STDERR "WARNING, WARNUNG, WARNING: maxprob was lower than cutprob, possible index/lucene bug\n"; 
    }



    if ( ((scalar @all_model) == 0) or ($all_model_top_path ne $DOCUMENT_MODELS_DIR)) # cached value not exist, or different 
    {
	@all_model = (); 
	my @subdir = get_subdirs($DOCUMENT_MODELS_DIR); 
	print STDERR "$DOCUMENT_MODELS_DIR has ", scalar (@subdir), " dirs (subdirs + itself) to follow;\n";
	foreach my $d (@subdir)
	{
	    #print STDERR "$d: "; 
	    my @ls = glob($d . "/*.model"); 
	    #print STDERR scalar(@ls), " model files\n"; 
	    
	    # converting file name into standard form. 
	    # so it is compatible with the file name in Index. 
	    foreach (@ls) 
	    {
		s/\/\.\//\//g;  # /./ -> /
	    }
	    push @all_model, @ls; 
	}
	$all_model_top_path = $DOCUMENT_MODELS_DIR; 
    }

    #print "$_ \n" foreach (@document_model); 
    #print "===***===\n"
    #print "$_ \n" foreach (@all_model); 
    foreach (@all_model)
    {
	if ($result{$_})
	{
	    $final_result{$_} = $result{$_} if ($result{$_}); 
	}
	else
	{
	    $final_result{$_} = $min_prob; 
	}
    }
    # sanity check 
    foreach (keys %result)
    {
	unless ($final_result{$_} == $result{$_}) #(exists $final_result{$_})
	{
	    die "Internal sanity check failure: model result found by index-fetching not found in the final result. File name match failure? Bad code? (Blame Gil for this.)\n" 
	}
    }

    # Debug CODE 
    # cutpoint average & all average 
    if (0) #($DEBUG)
    {
	my @ca = values %result; 
	print "average logprob from the cut point ", scalar (@ca), " doc-models:", mean(\@ca), "\n"; 
	my @aa = values %final_result; 
	print "average logprob from the all ", scalar(@aa)," (approximated, min-fill) doc-models:", mean(\@aa), "\n"; 
    }

    # done. return the result.
    print STDERR "Per model probability now completed\n"; 
    return \%final_result; 
}


# P_h_t_multithread_index 
# same as P_h_t_multithread, but this will get index path, instead of glob path
# and will do the same thing 
sub P_h_t_multithread_index
{
    # argument: hypothesis, text, lambda, collection model path, document model glob, document index path 
    # output (return): 
    # ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ). 

    # argument check 
    my @args = @_; 
    my $hypothesis = shift @args; 
    my $text = shift @args; 
    die "Something wrong, either hypothesis or text is missing\n" unless ($hypothesis and $text); 

    # calculate P(t) for each document model 
    print STDERR $text, "\n"; 
    my $text_per_doc_href = P_t_multithread_index($text, @args); # remaining @args will be checked there 
    # calculate P(t) overall 
    my $P_t; 
    my $nonOOV_len_t = count_non_zero_element (@collection_seq); # @collection_seq holds current collection seq. 

    print STDERR "P(t) is : "; 
    {
	my @t = values %{$text_per_doc_href}; 
	$P_t = mean(\@t); # (on uniform P(d) )
    }
    my $P_pw_t = $P_t / $nonOOV_len_t; 
    print STDERR "$P_t, length $nonOOV_len_t, normalized P_pw(t) is: $P_pw_t\n"; 
    # dcode 
    export_hash_to_file($text_per_doc_href, "Pt_per_doc.txt"); 

    # calculate P(h) for each model 
    print STDERR $hypothesis, "\n"; 
    my $hypo_per_doc_href = P_t_multithread_index($hypothesis, @args); 

    # calculate P(h) overall 
    my $P_h; 
    my $nonOOV_len_h = count_non_zero_element(@collection_seq); # holds current collection seq
 
    print STDERR "P(h) is : ";
    {
	my @h = values %{$hypo_per_doc_href}; 
	$P_h = mean(\@h); # (on uniform P(d) ) 
    }
    my $P_pw_h = $P_h / $nonOOV_len_h; 
    print STDERR "$P_h, length $nonOOV_len_h, normalized P_pw(h) is: $P_pw_h\n"; 
    # dcode
    export_hash_to_file($hypo_per_doc_href, "Ph_per_doc.txt"); 

    # calculate P(h|t,d) for each model 
    # note this %weighted is *non-normalized weight* (for evidence) 
    # and not the final prob. 
    print STDERR "calculating weighted contribution (evidence) for each doc\n"; 
    my %weighted; 
    my @text;
    my @hypo; 
    {
	foreach (keys %{$text_per_doc_href})
	{
	    $weighted{$_} = $text_per_doc_href->{$_} + $hypo_per_doc_href->{$_}; 
	    push @text, $text_per_doc_href->{$_}; 
	    push @hypo, $hypo_per_doc_href->{$_}; 
	}
    }
    # dcode
    export_hash_to_file(\%weighted, "PtPh_per_doc.txt"); 

    # calculate P(h|t) overall (that is, P(h|t,d)) 
    # WARNING: we made sure in the previous step, @text and @hypo sorted on the same 
    # list of files. That means that $text[$n] and $hypo[$n] came from the same doc.
    # This must be guaranteeded! 
    print STDERR "Calculating the weighted sum\n"; 
    my $P_h_given_t = weighted_sum(\@text, \@hypo); 
    #print @text, @hypo;     #dcode 
    my $P_pw_h_given_t = $P_h_given_t / $nonOOV_len_h; 
    print STDERR "P(h|t) is (logprob):  $P_h_given_t \t P_pw(h|t) is $P_pw_h_given_t\n"; 
    # calculate P(h|t) / P(h), as supporting measure. 
    my $gain = ($P_h_given_t - $P_h); 
    print STDERR "log (P(h|t) / P(h)) (PMI) is: ", $gain, "\n"; 
    print STDERR "Calculating the weighted sum for P(t|t)\n"; 
    my $P_t_given_t = weighted_sum(\@text, \@text); 
    my $P_pw_t_given_t = $P_t_given_t / $nonOOV_len_t; 

    my $bb_value = 10 ** ($P_pw_h_given_t - $P_pw_t_given_t); 
    print STDERR "P(t|t) is: $P_t_given_t, \t P_pw(t|t) is: $P_pw_t_given_t\n"; 
    print STDERR "P_pw(h|t) / P_pw(t|t) (BB) is: ", $bb_value, "\n"; 
    print STDERR "(all calculated from ", scalar(@text), " doc_model files, by using $APPROXIMATE_WITH_TOP_N_HITS top hits and fill-ins)\n"; 
    
    # ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ). 

    #return ($gain, $P_h_given_t, $P_h, $P_t, {%weighted}); 

    # returning
    # BB, PMI, P_pw_h_given_t, P_h_given_t - Ph, len_t, len_h, evidences_hash_ref
    return ($bb_value, $gain, $P_pw_h_given_t, ((10**$P_h_given_t) - (10**$P_h)), $nonOOV_len_t, $nonOOV_len_h, $P_h_given_t, $P_t, $P_h, {%weighted}); 

}

sub log10 {
    my $n = shift;
    return log($n)/log(10);
}

sub count_non_zero_element
{
    my $count = 0; 
    foreach (@_)
    {
	$count ++ unless ($_ == 0);
    }
    return $count; 
}

sub get_path_from_docid
{
    # note that : our $DOCUMENT_MODELS_DIR = "./models/document"; 
    my $id = shift; 
    die "invalid doc id: %id" unless ($id); 

    $id =~ /(.+?)_(.+?)_(\d\d\d\d)(\d\d)(\d\d)\./; 
    my $agency = $1; 
    my $lang = $2; 
    my $year = $3; 
    my $month = $4; 
    my $date = $5; 

    die "something wrong with the id: $id" unless ($date); 

    my $path = "/" . (lc ($agency)) . "_" . (lc ($lang)) . "_" . $year . $month . "/" . $date . "/"; 
    
    $path = $DOCUMENT_MODELS_DIR . $path . $id; 
    return $path; 
}

# SOLR based P_t_index 
sub P_t_index
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
	die unless (-e $_[3]); 
	$DOCUMENT_MODELS_DIR = $_[3]; 
    }

    my $hits_aref = solr_query($text); 
    print STDERR "Search hits returned.\n"; 

    # sanity check 
    my $hit_size = scalar (@{$hits_aref}); 
    warn "$text resulted no hits in plucene index" unless ($hit_size); 

    #my $total_doc_size; #deprecated. remove when all code ready. 

    # prepare list of models 
    my @document_model; 
    
    if ( $APPROXIMATE_WITH_TOP_N_HITS > 0 )
    { 	# use top N only. 
	my $n = 0; 
	foreach (@{$hits_aref}) # hits_aref is already sorted with search hit score, top first. 
	{
	    my $docid = $_; 
	    my $doc_full_path = get_path_from_docid($docid); 
	    push @document_model, ($doc_full_path . ".model"); 
	    $n++; 
	    last if ($n >= $APPROXIMATE_WITH_TOP_N_HITS); 
	}
    }
    else 
    {   # use all of them. 
	foreach (@{$hits_aref}) 
	{
	    my $docid = $_; 
	    my $doc_full_path = get_path_from_docid($docid); 
	    push @document_model, ($doc_full_path . ".model"); 
	}
    }
    
    undef $hits_aref; # not really needed but. 

    # call P_coll() 
    print STDERR "Calculating collection model logprob (to be interpolated)";  
    my @r = P_coll($text); # return value already saved in global @collection_seq
    my $coll_logprob = lambda_sum2(1, \@r, \@r); 
    print STDERR $coll_logprob, "\n"; 

    # for each model, call P_doc()     
    print STDERR "Calculating per-document model logprobs for ", scalar(@document_model), " files \n"; 

    # generate the threads, and run them with 1/number_thread array parts. 
    my @thread; 
    my $n = int ((scalar (@document_model)) / ($NUM_THREAD+0.0)); 
    my $start = 0; 
    my $end = $n-1; 

    for (my $i=0; $i < $NUM_THREAD; $i++)
    {
	# dcode
	#print STDERR "$start - $end\n"; 
	#print STDERR "$document_model[$start] - $document_model[$end]\n"; 

    	($thread[$i]) = threads->create(\&P_d_runner, @document_model[$start .. $end]); # () needed: array context. see http://perldoc.perl.org/threads.html#THREAD-CONTEXT

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

    # for debug code 
    my $max_prob = P_doc($document_model[0]); 
    my $cut_prob = 0; 
    #if ($APPROXIMATE_WITH_TOP_N_HITS < (scalar @document_model))
    my $last = $APPROXIMATE_WITH_TOP_N_HITS -1; 
    $last = ($hit_size - 1) if ($last > ($hit_size - 1)); 
    $cut_prob = P_doc($document_model[$last]); 

    # now, fill in the prob of "no-hit" document models 
    # first, calculate the minimum no-hit prob. 
    my %final_result; 
    my $min_prob; 
    {
	my @t; 
	push @t, 0 foreach (@r); 
	$min_prob = lambda_sum2($LAMBDA, \@t, \@r); 
    }

    # get all docmodel list 

    print STDERR "\nCalculating per-doc prob for hits done. Filling in min-prob for no-hits\n";     
    print STDERR "(min prob fillvalue is: $min_prob)\t (maxprob was: $max_prob)\t (cutpoint has: $cut_prob)\n"; 
    if ($max_prob < $cut_prob)
    {
	print STDERR "WARNING, WARNUNG, WARNING: maxprob was lower than cutprob, possible index/lucene bug\n"; 
    }

    if ( ((scalar @all_model) == 0) or ($all_model_top_path ne $DOCUMENT_MODELS_DIR)) # cached value not exist, or different 
    {
	@all_model = (); 
	my @subdir = get_subdirs($DOCUMENT_MODELS_DIR); 
	print STDERR "$DOCUMENT_MODELS_DIR has ", scalar (@subdir), " dirs (subdirs + itself) to follow;\n";
	foreach my $d (@subdir)
	{
	    #print STDERR "$d: "; 
	    my @ls = glob($d . "/*.model"); 
	    #print STDERR scalar(@ls), " model files\n"; 
	    
	    # converting file name into standard form. 
	    # so it is compatible with the file name in Index. 
	    foreach (@ls) 
	    {
		s/\/\.\//\//g;  # /./ -> /
	    }
	    push @all_model, @ls; 
	}
	$all_model_top_path = $DOCUMENT_MODELS_DIR; 
    }

    #print "$_ \n" foreach (@document_model); 
    #print "===***===\n"
    #print "$_ \n" foreach (@all_model); 
    foreach (@all_model)
    {
	if ($result{$_})
	{
	    $final_result{$_} = $result{$_} if ($result{$_}); 
	}
	else
	{
	    $final_result{$_} = $min_prob; 
	}
    }
    # sanity check 
    foreach (keys %result)
    {
	unless ($final_result{$_} == $result{$_}) #(exists $final_result{$_})
	{
	    die "Internal sanity check failure: model result found by index-fetching not found in the final result. File name match failure? Bad code? (Blame Gil for this.)\n" 
	}
    }

    # Debug CODE 
    # cutpoint average & all average 
    if (0) #($DEBUG)
    {
	my @ca = values %result; 
	print "average logprob from the cut point ", scalar (@ca), " doc-models:", mean(\@ca), "\n"; 
	my @aa = values %final_result; 
	print "average logprob from the all ", scalar(@aa)," (approximated, min-fill) doc-models:", mean(\@aa), "\n"; 
    }

    # done. return the result.
    print STDERR "Per model probability now completed\n"; 
    return \%final_result; 
}


# SOLR based P(h|t). 
sub P_h_t_index
{
    # argument: hypothesis, text, lambda, collection model path, document model top path 
    # output (return): 
    # ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ). 

    # argument check 
    my @args = @_; 
    my $hypothesis = shift @args; 
    my $text = shift @args; 
    die "Something wrong, either hypothesis or text is missing\n" unless ($hypothesis and $text); 

    # calculate P(t) for each document model 
    print STDERR $text, "\n"; 
    my $text_per_doc_href = P_t_index($text, @args); # remaining @args will be checked there 
    # calculate P(t) overall 
    my $P_t; 
    my $nonOOV_len_t = count_non_zero_element (@collection_seq); # @collection_seq holds current collection seq. 

    print STDERR "P(t) is : "; 
    {
	my @t = values %{$text_per_doc_href}; 
	$P_t = mean(\@t); # (on uniform P(d) )
    }
    my $P_pw_t = $P_t / $nonOOV_len_t; 
    print STDERR "$P_t, length $nonOOV_len_t, normalized P_pw(t) is: $P_pw_t\n"; 
    # dcode 
    export_hash_to_file($text_per_doc_href, "Pt_per_doc.txt"); 

    # calculate P(h) for each model 
    print STDERR $hypothesis, "\n"; 
    my $hypo_per_doc_href = P_t_index($hypothesis, @args); 

    # calculate P(h) overall 
    my $P_h; 
    my $nonOOV_len_h = count_non_zero_element(@collection_seq); # holds current collection seq
 
    print STDERR "P(h) is : ";
    {
	my @h = values %{$hypo_per_doc_href}; 
	$P_h = mean(\@h); # (on uniform P(d) ) 
    }
    my $P_pw_h = $P_h / $nonOOV_len_h; 
    print STDERR "$P_h, length $nonOOV_len_h, normalized P_pw(h) is: $P_pw_h\n"; 
    # dcode
    export_hash_to_file($hypo_per_doc_href, "Ph_per_doc.txt"); 

    # calculate P(h|t,d) for each model 
    # note this %weighted is *non-normalized weight* (for evidence) 
    # and not the final prob. 
    print STDERR "calculating weighted contribution (evidence) for each doc\n"; 
    my %weighted; 
    my @text;
    my @hypo; 
    {
	foreach (keys %{$text_per_doc_href})
	{
	    $weighted{$_} = $text_per_doc_href->{$_} + $hypo_per_doc_href->{$_}; 
	    push @text, $text_per_doc_href->{$_}; 
	    push @hypo, $hypo_per_doc_href->{$_}; 
	}
    }
    # dcode
    export_hash_to_file(\%weighted, "PtPh_per_doc.txt"); 

    # calculate P(h|t) overall (that is, P(h|t,d)) 
    # WARNING: we made sure in the previous step, @text and @hypo sorted on the same 
    # list of files. That means that $text[$n] and $hypo[$n] came from the same doc.
    # This must be guaranteeded! 
    print STDERR "Calculating the weighted sum\n"; 
    my $P_h_given_t = weighted_sum(\@text, \@hypo); 
    #print @text, @hypo;     #dcode 
    my $P_pw_h_given_t = $P_h_given_t / $nonOOV_len_h; 
    print STDERR "P(h|t) is (logprob):  $P_h_given_t \t P_pw(h|t) is $P_pw_h_given_t\n"; 
    # calculate P(h|t) / P(h), as supporting measure. 
    my $gain = ($P_h_given_t - $P_h); 

    print STDERR "Calculating the weighted sum for P(t|t)\n"; 
    my $P_t_given_t = weighted_sum(\@text, \@text); 
    my $P_pw_t_given_t = $P_t_given_t / $nonOOV_len_t; 

    my $per_word_minus = (10 ** $P_pw_h_given_t) - (10 ** $P_pw_h); 
    my $bb_value = 10 ** ($P_pw_h_given_t - $P_pw_t_given_t); 
#    print STDERR "P(t|t) is: $P_t_given_t, \t P_pw(t|t) is: $P_pw_t_given_t\n"; 
    print STDERR "===\n"; 
    print STDERR "1] P_pw(h|t) / P_pw(t|t) (BB) is: ", $bb_value, "\n";
    print STDERR "2] log (P(h|t) / P(h)) (PMI) is: ", $gain, "\n"; 
    print STDERR "3] P_pw(h|t) (per word P(h|t)) is: ", $P_pw_h_given_t, "\n"; 
    print STDERR "4] P_pw(h|t) - P_pw(h) (MINUS) is : ", $per_word_minus, "\n"; 
    print STDERR "(all calculated from ", scalar(@text), " doc_models, by approx with $APPROXIMATE_WITH_TOP_N_HITS top hits)\n"; 
    print STDERR "===\n"; 
    
    # ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ). 

    #return ($gain, $P_h_given_t, $P_h, $P_t, {%weighted}); 

    # returning
    # BB, PMI, P_pw_h_given_t, P_pw(h|t) - P_pw(h), len_t, len_h, evidences_hash_ref
    return ($bb_value, $gain, $P_pw_h_given_t, $per_word_minus, $nonOOV_len_t, $nonOOV_len_h, $P_h_given_t, $P_t, $P_h, {%weighted}); 
    #return ($bb_value, $gain, $P_pw_h_given_t, ((10**$P_h_given_t) - (10**$P_h)), $nonOOV_len_t, $nonOOV_len_h, $P_h_given_t, $P_t, $P_h, {%weighted}); 
}


1; 

__END__

=head1 NAME

(proto) condprob - a conditional probability calculation tools for SRILM Language Models. 

=head1 SYNOPSIS

    use condprob qw(:DEFAULT $NUM_THREAD); 

=head1 DESCRIPTION 

well, some discription. 


