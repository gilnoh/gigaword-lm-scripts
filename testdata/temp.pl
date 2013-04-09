use strict;

use Plucene; 
use Plucene::Document; 
use Plucene::Document::Field; 
use Plucene::Search::IndexSearcher; 
use Plucene::Analysis::SimpleAnalyzer; 
use Plucene::Analysis::Standard::StandardAnalyzer; 
use Plucene::Index::Writer; 
use Plucene::QueryParser; 

# a simple test. 

# prepare query
my $parser = Plucene::QueryParser->new({
    analyzer => Plucene::Analysis::SimpleAnalyzer->new(),
    default  => "text" # Default field for non-specified queries
				       });

#my $query = $parser->parse('text:"football" AND text:"hiddink" AND text:"dance"'); 
my $query = $parser->parse('football news');

# search 
my $searcher = Plucene::Search::IndexSearcher->new("models_index");
my @docs;
my $hc = Plucene::Search::HitCollector->new(collect => sub {
    my ($self, $doc, $score) = @_;
    push @docs, $searcher->doc($doc);
					    
					    });

$searcher->search_hc($query => $hc);

foreach my $doc (@docs)
{
    my Plucene::Document::Field @field = $doc->fields; 
    foreach (@field)
    {
	print "name: ", $_->name()," \tstring: ", $_->string(), "\n"; 
    }
}