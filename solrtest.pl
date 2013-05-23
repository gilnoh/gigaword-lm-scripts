# testing SOLR connection. 

use warnings; 
use strict; 

use WebService::Solr; 
use WebService::Solr::Document; 
use WebService::Solr::Query; 

# let's assume local host 
my $url = "http://localhost:8983/solr"; 

my $solr = WebService::Solr->new;

# prepare a few docs 
my $field1 = WebService::Solr::Field->new( id => 'Gil01' );
my $field2 = WebService::Solr::Field->new( name => 'First Document Title' ); 

my $doc1 = WebService::Solr::Document->new($field1, $field2);

my $field3 = WebService::Solr::Field->new( id => 'Gil02' ); 
my $field4 = WebService::Solr::Field->new( name => 'Another document name!' ); 

my $doc2 = WebService::Solr::Document->new($field3, $field4);  

#my @docs; 
#push @docs, $doc1;
#push @docs, $doc2; 
 
#$solr->add( $doc2 );

# my $response = $solr->search( $query );
# for my $doc ( $response->docs ) {
#     print $doc->value_for( $id );
#     print $doc->value_for( $name ); 
# }

my $query  = WebService::Solr::Query->new( { name => 'document' } );
my $response = $solr->search ( $query ); 
for my $doc ( $response->docs ) {
    print $doc->value_for( 'id' ), "\t";
    print $doc->value_for( 'name' ), "\n"; 
}
