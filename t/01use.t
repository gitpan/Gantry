use Test::More qw(no_plan); 

# server
use_ok('Gantry::Server');

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
