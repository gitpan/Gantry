use Test::More qw(no_plan);
use strict;

# template toolkit plugin
use_ok('Gantry::Template::TT');
can_ok('Gantry::Template::TT', 'do_action', 'do_error', 'do_process' );


