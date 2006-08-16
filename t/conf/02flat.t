use strict;

use Test::More tests => 12;
use Test::Exception;
use File::Spec;

BEGIN {
    eval { require Gantry::Conf; };
    my $skip_all = 1 if ( $@ );

    SKIP: {
        skip "couldn't use Gantry::Conf (missing dependencies?)", 12
                if $skip_all;
    }
    exit 0 if $skip_all;

    # If Gantry::Conf ever decides to export add this:
    # use Gantry::Conf;
}

#-------------------------------------------------------------------------
# no params supplied
#-------------------------------------------------------------------------
throws_ok { Gantry::Conf->retrieve(); }
          qr/No param/,
          'no parameter list';

#-------------------------------------------------------------------------
# no instance supplied
#-------------------------------------------------------------------------

throws_ok { Gantry::Conf->retrieve( {} ); }
          qr/No instance given/,
          'missing instance';

#-------------------------------------------------------------------------
# can't find gantry.conf
#-------------------------------------------------------------------------

my $bad_gconf = File::Spec->catfile( qw( t conf flat missing_gantry.conf ) );

throws_ok
    {
        Gantry::Conf->retrieve(
            {
                instance    => 'missing',
                config_file => $bad_gconf
            }
        );
    }
    qr/Configuration file .* does not exist/,
    'no such gantry conf file';

#-------------------------------------------------------------------------
# found gantry.conf, but your instance isn't in it
#-------------------------------------------------------------------------

$bad_gconf = File::Spec->catfile( qw( t conf flat badgantry.conf ) );
throws_ok
    {
        Gantry::Conf->retrieve(
            {
                instance    => 'missing',
                config_file => $bad_gconf
            }
        )
    }
    qr/Unable to find 'missing'/,
    'instance not included';

#-------------------------------------------------------------------------
# found gantry.conf and your instance, but its file is missing
#-------------------------------------------------------------------------

throws_ok
    {
        Gantry::Conf->retrieve(
            {
                instance    => 'sample',
                config_file => $bad_gconf
            }
        );
    }
    qr/Unable to load.* /,
    'config file missing';

#-------------------------------------------------------------------------
# found gantry.conf and your instance, but its ConfigureVia method is unknown
#-------------------------------------------------------------------------

$bad_gconf = File::Spec->catfile( qw( t conf flat badgantry2.conf ) );
throws_ok
    {
        Gantry::Conf->retrieve(
            {
                instance    => 'sample',
                config_file => $bad_gconf
            }
        )
    }
    qr/No such ConfigureVia method/,
    'misspelled or unknown ConfigureVia method';

#-------------------------------------------------------------------------
# single flat file no <> directives
#-------------------------------------------------------------------------

my $gconf = File::Spec->catfile( qw( t conf flat gantry.conf ) );

my $simple_conf = Gantry::Conf->retrieve(
    {
        instance    => 'sample',
        config_file => $gconf
    }
);
is_deeply( $simple_conf, { var => 'value', num => 4 }, 'parsed simple conf' );

#-------------------------------------------------------------------------
# two flat files in a single ConfigureVia statement
#-------------------------------------------------------------------------

$gconf = File::Spec->catfile( qw( t conf flat user.conf ) );

my $using_conf = Gantry::Conf->retrieve(
    {
        instance    => 'sample',
        config_file => $gconf
    }
);

is_deeply(
    $using_conf,
    { var => 'value', num => 4, greeting => 'Hello', signoff => 'Bye' },
    'two flat files one ConfigureVia'
);

#-------------------------------------------------------------------------
# two flat files in two ConfigureVia statements
#-------------------------------------------------------------------------

$gconf = File::Spec->catfile( qw( t conf flat user2.conf ) );

$using_conf = Gantry::Conf->retrieve(
    {
        instance    => 'sample',
        config_file => $gconf
    }
);

is_deeply(
    $using_conf,
    {
        var      => 'value',
        num      => 4,
        greeting => 'Hello',
        signoff  => 'Bye',
    },
    'two flat files two ConfigureVias'
);

#-------------------------------------------------------------------------
# level fishing - top level
#-------------------------------------------------------------------------

$gconf = File::Spec->catfile( qw( t conf flat user.conf ) );

$using_conf = Gantry::Conf->retrieve(
    {
        instance    => 'levels',
        config_file => $gconf,
        location    => '/'
    }
);

is_deeply(
    $using_conf,
    {
        level_name => 'top',
        all_share  => 5,
        reset      => 5,
    },
    'level fishing - top level'
);

#-------------------------------------------------------------------------
# level fishing - second level
#-------------------------------------------------------------------------

$using_conf = Gantry::Conf->retrieve(
    {
        instance    => 'levels',
        config_file => $gconf,
        location    => '/second'
    }
);

is_deeply(
    $using_conf,
    {
        level_name => 'second',
        all_share  => 5,
        reset      => 4,
    },
    'level fishing - second level'
);

#-------------------------------------------------------------------------
# level fishing - third level
#-------------------------------------------------------------------------

$using_conf = Gantry::Conf->retrieve(
    {
        instance    => 'levels',
        config_file => $gconf,
        location    => '/second/nested'
    }
);

is_deeply(
    $using_conf,
    {
        level_name => 'second.nested',
        all_share  => 5,
        reset      => 2,
    },
    'level fishing - third level'
);
