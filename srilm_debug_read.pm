# a perl module to read debug module 

require Exporter;
@ISA = qw(Exporter); 
@EXPORT = qw(read_debug3 read_debug3_log read_debug3_p); 

sub read_debug3_p {
    # return probability value itself (non-log) 
    my @result; 
    @pline = read_debug3(@_);
    foreach (@pline)
    {
	/.\] (.+?) \[ /; 
	push @result, $1; 
    }
    return @result; 
}

sub read_debug3_log {
    # return log probability part of each word 
    my @result; 
    @pline = read_debug3(@_); 
    foreach (@pline)
    {
	/ \[ (.+?) \] \/ 1/; 
	push @result, $1 
    }
    return @result; 
}

sub read_debug3 {
    # print STDERR @lines; 
    # all ngram -ppl [input] -debug 3 outputs will be passed 
    # to this method. 
    # first line, original sentence 
    # then each line, "\t" p (something) 
    # finally, some closeing things 
    # let's pick all lines with \t, since we are assuming single sentence  
    my @lines = @_; 
    my @result; 
    foreach (@lines)
    {
	push @result, $_ if (/^\t/); 
    }
    return @result; 

}

1; 
