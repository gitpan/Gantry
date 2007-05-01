use strict;
use Test::More tests => 2;

BEGIN {
    eval { require Cache::FastMmap; };
    my $skip_all = ( $@ ) ? 1 : 0;

    SKIP: {
        skip "Gantry::Plugins::Cache::FastMmap requires Cache::FastMmap", 2
                if $skip_all;
                
        use_ok( 'Gantry::Plugins::Cache' );        
        use_ok( 'Gantry::Plugins::Cache::FastMmap' );
    }
}
