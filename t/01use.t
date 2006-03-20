use Test::More tests => 1;

eval "use mod_perl;";
my $mp1 = 1 unless $@;

eval "use mod_perl2;";
my $mp2 = 1 unless $@;

if ( ! $mp1 && ! $mp2 ) {
    diag( "mod_perl NOT INSTALLED" );
    fail( 'mod_perl' );
}
else {
	pass( 'mod_perl' );
}
			
