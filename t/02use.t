use Test::More tests => 35;

eval "use mod_perl;";
my $mp1 = 1 unless $@;

eval "use mod_perl2;";
my $mp2 = 1 unless $@;

if ( ! $mp1 && ! $mp2 ) {
	diag( "mod_perl NOT INSTALLED" );
}
else {
	diag( "mod_perl version: " . $mod_perl::VERSION . " detected" );
}

use_ok('Gantry');
use_ok('Gantry::Stash');
use_ok('Gantry::Stash::View');
use_ok('Gantry::Stash::View::Form');
use_ok('Gantry::Stash::Controller');

# Engine methods
my @engine_methods = qw(
	header_out
	err_header_out
	status_const
	send_http_header
	header_in
	apache_param_hash
	apache_request
	get_arg_hash
	remote_ip
	base_server
	port
	server_root
);

if ( $mp1 && $mod_perl::VERSION =~ /^1\.99/ ) {
	eval { require Apache::Request; };
	
	if ( $@ ) { 
		fail( 'Apache::Request' ); 
	}
	else { 
		pass( 'Apache::Request' ); 
	}
	
	SKIP: {
		skip( "Apache Request not installed", 2 ) if $@;
		
		use_ok('Gantry::Engine::MP19');
		can_ok('Gantry::Engine::MP19', @engine_methods);
	}
}
elsif ( $mp1 ) {
	use_ok('Gantry::Engine::MP13');
	can_ok('Gantry::Engine::MP13', @engine_methods);
}
elsif ( $mp2 ) {
	use_ok('Gantry::Engine::MP20');
	can_ok('Gantry::Engine::MP20', @engine_methods);
}

# template toolkit plugin
use_ok('Gantry::Template::TT');
can_ok('Gantry::Template::TT', 'do_action', 'do_error', 'do_process' );

# template default plugin
can_ok('Gantry::Template::Default', 'do_action', 'do_error', 'do_process' );

# plugins
use_ok('Gantry::Plugins::AutoCRUD');
use_ok('Gantry::Plugins::CRUD');
use_ok('Gantry::Plugins::Calendar');

# utilities
use_ok('Gantry::Utils::DB');
use_ok('Gantry::Utils::SQL');
use_ok('Gantry::Utils::Validate');
use_ok('Gantry::Utils::HTML');
use_ok('Gantry::Utils::CDBI');
use_ok('Gantry::Utils::AuthCDBI');
use_ok('Gantry::Utils::CRUDHelp');

# auth control models
use_ok('Gantry::Control::Model::auth_users');
use_ok('Gantry::Control::Model::auth_pages');
use_ok('Gantry::Control::Model::auth_groups');
use_ok('Gantry::Control::Model::auth_group_members');

# auth control handlers
use_ok('Gantry::Control::C::Access');
can_ok('Gantry::Control::C::Access', 'handler' );

use_ok('Gantry::Control::C::Authen');
can_ok('Gantry::Control::C::Authen', 'handler' );

use_ok('Gantry::Control::C::Authz');
can_ok('Gantry::Control::C::Authz', 'handler' );

use_ok('Gantry::Control::C::Authz::PageBased');
can_ok('Gantry::Control::C::Authz::PageBased', 'handler' );

# auth frontend controllers
use_ok('Gantry::Control::C::Users');
use_ok('Gantry::Control::C::Pages');
use_ok('Gantry::Control::C::Groups');
