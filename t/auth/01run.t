#!/usr/bin/perl

use Test::More;
use strict;
no warnings;

use lib qw( ../lib );
use Gantry qw{ -Engine=CGI -TemplateEngine=TT };
use Gantry::Server;
use Gantry::Engine::CGI;

diag( "" );
diag( "Do you want to run Gantry Auth application tests [no]?" );
my $run_tests = <STDIN>;
chomp( $run_tests );
$run_tests ||= 'no';

my( $dbconn, $dbuser, $dbpass );
if ( $run_tests =~ /^y/i ) {
	plan qw(no_plan);
	
	diag( "Enter database connection string [dbi:Pg:dbname=master_auth]?" );
	$dbconn = <STDIN>;
	chomp( $dbconn );
	$dbconn ||= 'dbi:Pg:dbname=master_auth';

	diag( "Enter database user [apache]?" );
	my $dbuser = <STDIN>;
	chomp( $dbuser );
	$dbuser ||= 'apache';

	diag( "Enter database password []?" );
	my $dbpass = <STDIN>;
	chomp( $dbpass );
	$dbpass ||= '';
}
else {
	plan skip_all => 'Gantry Auth Application test';
}


# test must contain valid template paths to the core gantry templates
# and the application templates

my $cgi = Gantry::Engine::CGI->new( {
    config => {
        'app_rootp' => '/site',
        'auth_dbconn'   => $dbconn,
        'auth_dbuser'   => $dbuser,
        'auth_dbpass'   => $dbpass,
       	'root'      => ( "../../root:root" )
    },
    locations => {
        '/site/users'       => 'Gantry::Control::C::Users',
        '/site/groups'      => 'Gantry::Control::C::Groups',
        '/site/pages'       => 'Gantry::Control::C::Pages',
    },
} );

my @tests = qw`
    /site/users
    /site/groups
    /site/pages
    /site/pages2
    /site/pages
    /site/pages
    /site/pages
    /site/pages
`;

my $server = Gantry::Server->new();
$server->set_engine_object( $cgi );

foreach my $location ( @tests ) {
    my( $status, $page ) = $server->handle_request_test( $location );
    ok( $status eq '200',
        "expected 200, received $status for $location" );

    if ( $status ne '200' ) {
        print STDERR $page . "\n\n";
    }
}


