package Gantry::Docs::Tutorial;

=head1 Name

Gantry::Docs::Tutorial - The Gantry Tutorial

=head1 Introduction

Gantry is a mature web framework, released in late 2005 onto
an unsuspecting world.  For more information on the framework, its
features and history, see Gantry::Docs::About.

Here we will explore the basic workings of Gantry by constructing a
very simple application.  Don't let the simplicity of this example 
fool you -- this framework has extreme flexibility in delivering
applications with web and scripted components.  The example in
this document is only to get you started.

This document begins by describing a simple one-table management application.
It walks through the process of building the application.  Then,
it shows a tool -- called Bigtop -- which can be used to build the application
from a relatively small configuration file.  Finally, it shows how
to add another table and regenerate the app via Bigtop.

=head1 Sample App Description

I'm worried about my wife's address book.  There is only one copy and
without it, we would lose track of many of our friends and some of
our relatives.  I want to put my wife's address book into a database,
but allow her to use it through a web interface.

Here are the things that Lisa tracks:

=over 4

=item name

the name of a person or nuclear family

=item address

postal address, so we can send toys to the kids etc.

=item phone

one or more numbers (email addresses are in the margin, but that
will have to wait for version 1.1)

=back

This leads to one table:

    CREATE SEQUENCE address_seq;
    CREATE TABLE address (
        id int4 PRIMARY KEY DEFAULT NEXTVAL( 'address_seq' ),
        name   varchar,
        street varchar,
        city   varchar,
        state  varchar,
        zip    varchar,
        phone  varchar
    );

The application needs to show all the addresses in a single table,
allow for adding new ones and editing or deleting existing ones.  To make
it easier to accomodate Lisa's international family and friends, we won't
do any validation of the data -- except to make sure she enters
some.  For example, this will allow her to wedge several numbers
(home, cell, etc.) into the phone field.

=head1 Hand-writing the Sample App

After creating a directory called Apps-Address, I made a lib subdirectory
for the code.  (You could use h2xs to help with the initial steps.  Or,
you could use Bigtop, as I did, see L<Using Bigtop> below.)

There are three modules in this application:

=over 4

=item Apps::AddressBook

the base module

=item Apps::AddressBook::Address

the controller for the address table

=item Apps::AddressBook::Model::address

the object relational mapper

=back

We'll walk through each of these in a subsection, showing the code
with commentary interspersed.  After our tour I'll show the modules
again without the commentary, so you can see how they look when whole,
in L<Complete Code Listings>.

=head2 Apps::AddressBook

The job of the base module is to load Gantry.  If there was any
app specific configuration info, this would be the place to handle
it (see below for an example).  The base module is also a nice home
for code the other modules need to share.

Here is our module (without its documentation but with commentary
interspersed):

    package Apps::AddressBook;

    use strict;

    our $VERSION = '0.01';

It begins like any other module...

    use Gantry qw{ -Engine=MP13 -TemplateEngine=TT };

    our @ISA = ( 'Gantry' );

...but, it uses Gantry with an engine (mod_perl 1.3 in this case) and
a template engine (Template Toolkit).

Note that somewhere you need to use Gantry with the -Engine and
-TemplateEngine options.  You could do that in your httpd.conf
or CGI dispatching script.  If you do that, reduce the previous two lines to:

    use base 'Gantry';

Doing that would add the flexibilty of redeploying the application
from one engine to another with absolutely no code changes.  Note
that wherever you decide to use Gantry with the -Engine and -TemplateEngine
flags, you cannot use base, since that pragma has no way to pass
import requests to the base module.

    use Apps::AddressBook::Address;

    1;

For the convenience of future readers, the base module has an explicit use
for the single controller Apps::AddressBook::Address (which we will see below).
This is purely for documentation.

Gantry.pm handles a set of standard configuration parameters.
If you need to handle others, implement an init sub and accessors for them.
It's usually easier to dispatch to SUPER for the standard parameters, then
handle your app specific ones.  For example, an init to catch an smtp host
name might look like this:

    sub init {
        my ( $self ) = @_;

        # process SUPER's init code
        $self->SUPER::init( );

        $self->smtp_host( $self->fish_conf( 'smtp_host' ) || '' );
    } # END init

Using fish_conf has two advantages over a more direct approach like this:

        $self->smtp_host( $self->r->dir_config( 'smtp_host' ) || '' );

First, using dir_config ties you to mod_perl.  Second, directly fishing
from the request object prevents a more general solution, like
Gantry::Conf (see Gantry::Conf::Tutorial for how to use that).

=head2 Apps::AddressBook::Address

This is the workhorse for this application.  It manages the CRUD (create,
retrieve, update, and delete) for address book rows.  Again, I'll include
it a piece at a time with running commentary.

    package Apps::AddressBook::Address;

    use strict;

    use base 'Apps::AddressBook';

It begins like any subclass.  Note that it is a subclass of Apps::AddressBook
which is itself a subclass of Gantry.  The only handler sub is in Gantry.pm
(unless you count user authentication, but that's way ahead of our little
story about the vulnerable address book with the flowers on the cover).

    use Apps::AddressBook::Model::address qw( $ADDRESS );

Each table has a model in the Model namespace with the same name as the
table (note the case -- this exactly matches the sql shown in the previous
section).  The model exports an alias to its full name as $ADDRESS to
save us some typing when we use it.  It uses uc on the table's name to
make the alias more visible.

    use Gantry::Plugins::AutoCRUD;

This is the real key to avoiding work.  AutoCRUD handles create, update
and delete (we'll see retrieval in a minute).  This module is more of a
mixin than a plugin.  It exports four methods to us: do_add, do_edit,
do_delete, and form_name.  The last is just the name of the template
to use for add/edit input.  If you don't want the standard form.tt, that
comes with Gantry, don't import that method.  Instead, implement a
method which returns the name of your template file.

In gantry, the handler calls methods named do_* where the star is replaced
with a string from the url.  So the url for adding an entry to the
address book would be something like:

    http://somehost.example.com/address/add

where somehost.example.com is our host (or virtual host) and /address/add
is the requested page.  address is a Location in our apache conf and
add becomes do_add, the name of the method to execute.  Using the do_ prefix
has two advantages.  First, since url pieces are used directly, it keeps
people from running non-handlers by clever url spoofing.  Second, and
for our company more importantly, it makes it clear which methods
are accessible, and which are not.  This aids us when we are modifying
a controller.  If it starts with do_ it can be reached via url.

    #-----------------------------------------------------------------
    # get_model_name( )
    #-----------------------------------------------------------------
    sub get_model_name {
        return $ADDRESS;
    }

Gantry::Plugins::AutoCRUD uses get_model_name to find out which model
class to use for create, update, delete, and lookups.

    #-----------------------------------------------------------------
    # text_descr( )
    #-----------------------------------------------------------------
    sub text_descr     {
        return 'address';
    }

Gantry::Plugins::AutoCRUD uses text_descr to fill in the blank in things
like:

    Delete _____?

Now we are coming to the real code.  The default action for a Location
in Gantry is do_main.  We usually use it to display a table with one
summary row for each database row like this.  It looks like this:

=for html <img src='http://www.usegantry.org/images/mainlist.png' alt='Main Listing Screen Shot' />

The code begins:

    #-----------------------------------------------------------------
    # $self->do_main(  )
    #-----------------------------------------------------------------
    sub do_main {
        my ( $self ) = @_;

        $self->stash->view->template( 'results.tt' );

Gantry objects store data for one page hit.  Much of the data you
should directly access is in the stash, which is a Gantry::Stash
object.  It provides accessors for all its data.  If you need additional
accessors feel free to add them.  Gantry objects are hashes whose keys
are usually formed from the attribute name like this:

    name      becomes    __NAME__

but sometimes things aren't perfect, so stick with the accessors.

One of the key things in the stash is the view.  It is a
Gantry::Stach::View object which holds data destined for the template
as well as the name of the template (which is set to 'results.tt' above).

        $self->stash->view->title( 'Address' );

The stash view title appears in the browser window border.

Now we need to put some data into the standard results.tt table.  We'll
start with the headings for the columns.

        my $data = {
            headings       => [
                'Name',
                'Phone Number',
            ],
            header_options => [
                {
                    text => 'Add',
                    link => $self->location() . "/add",
                },
            ],
        };

The template is expecting a hash reference as its data.  Two of the
keys are headings and header_options.  Headings are the labels for the
normal columns in table.  I could have included address here, but that
would only have added lines of code without really showing you anything.

The header_options appear at the right side of the table heading.  These
are things you can do without referencing a current row.  In this case,
only add is possible.  The link uses the location of the current page
with /add appended.  Clicking the link will cause Gantry to hit again,
when it will dispatch to do_add in AutoCRUD.

        my @rows = $ADDRESS->retrieve_all_for_main_listing();

The model will return an array of objects sorted in order by name through
the badly named retrieve_all_for_main_listing.  We can then walk that
array as shown here:

        foreach my $row ( @rows ) {
            my $id = $row->id;
            push(
                @{ $data->{rows} }, {
                    data => [
                        $row->name,
                        $row->phone,
                    ],
                    options => [
                        {
                            text => 'Edit',
                            link => $self->location() . "/edit/$id",
                        },
                        {
                            text => 'Delete',
                            link => $self->location() . "/delete/$id",
                        },
                    ],
                }
            );
        }

For each row, we need to hold onto the id (so we can use it in edit/delete
links), then push into the rows array of the data hash we are building for
results.tt.

Each row we push is a hash with two keys: data and options.  The
data is just the values from the model object for the column in the
output table (name and phone number here).  The options are the things
that can be done to the row.  Here, the user will be able to edit and
delete the row.  Those links go directly to do_delete and do_edit which
were exported by Gantry::Plugins::AutoCRUD.

Finally, we need to put the data into the stash:

        $self->stash->view->data( $retval );
    } # END do_main

The only other piece of the controller is the form to use for add and
edit.  AutoCRUD calls this method for you when the users visits
do_add and do_edit pages.  Call this method form.  If an edit triggered
the call, it will pass in the row as it stands in the database.

The following code produces this on the screen:

=for html <img src='http://www.usegantry.org/images/form.png' alt='Form Screen Shot' />

    #-----------------------------------------------------------------
    # $self->form( $row )
    #-----------------------------------------------------------------
    sub form {
        my ( $self, $row ) = @_;

        return {
            name       => 'address',
            row        => $row,
            legend     => $self->path_info =~ /edit/i ? 'Edit' : 'Add',
            fields     => [
                {
                    name  => 'name',
                    label => 'Name',
                    type  => 'text',
                },
                # other similar hashes ommitted
                # see Complete Code Lsting
            ],
        }
    } # END of form

    1;

The form method must return a hash reference whose keys are understood
by the form template (form.tt in our case).  Here's what the keys mean
to the standard form.tt:

=over 4

=item name

the name of the form

=item row

data from the database to use as a default (meaningful for edit)

=item legend

form.tt uses a fieldset, this is its legend

=item fields

an array reference of the input fields (more info below)

=back

Only one field is shown, because in our example they all look alike.  The
real code would need hashes just like the one above for street, city,
state, zip, and phone number.

Each member of the fields array is a hash.  There are lots of keys; here are
the ones I'm using:

=over 4

=item name

the name of the column in the database and the html form element

=item label

what the user sees next to the entry component

=item type

html form input type (choose from text, select, and textarea)

=back

Other keys control things like how wide the field is, etc.  See the
docs in form.tt for details.

That's the whole controller (save the #... where the other fields go
-- see below for L<Complete Code Listing>).

=head2 Apps::AddressBook::Model::address

To separate sql from the controller (and view) we use Gantry with an
Object-Relational Mapper (ORM).  For this example I will show
Class::DBI::Sweet, since it was the first one we used.  But, you can also
use Gantry's own native models inheriting from Gantry::Utils::Model -- or
any other ORM responding to the Class::DBI API -- without changing the
non-Model parts of the app.  With a bit of work on the controllers, you can
also use DBIx::Class.

Gantry provides its own base class to add to Class::DBI::Sweet, it is
L<Gantry::Utils::CDBI>.  Each model subclasses it and represents one table
in the database.  These classes are standard Class::DBI subclasses.  Here
is ours:

    package Apps::AddressBook::Model::address;
    use strict; use warnings;

    use base 'Gantry::Utils::CDBI', 'Exporter';

    our $ADDRESS = 'Apps::AddressBook::Model::address';

    our @EXPORT_OK = ( '$ADDRESS' );

Note that we export the alias for controllers to use when referring to
the model class.  This mitigates the length of the name.  Gantry does not
require you to do this.  If you prefer to type the name, feel free.

    Apps::AddressBook::Model::address->table   ( 'address'     );
    Apps::AddressBook::Model::address->sequence( 'address_seq' );
    Apps::AddressBook::Model::address->columns ( Primary   => qw/ id / );

    Apps::AddressBook::Model::address->columns (
        All       => qw/
            id
            name
            street
            city
            state
            zip
            phone
        /
    );

    1;

See the perldoc for Class::DBI and Class::DBI::Sweet for more details.

=head2 Complete Code Listings

SQL for database creation

    CREATE SEQUENCE address_seq;
    CREATE TABLE address (
        id int4 PRIMARY KEY DEFAULT NEXTVAL( 'address_seq' ),
        name   varchar,
        street varchar,
        city   varchar,
        state  varchar,
        zip    varchar,
        phone  varchar
    );

Apps::AddressBook

    package Apps::AddressBook;

    use strict;

    our $VERSION = '0.01';

    use Gantry qw{ -Engine=MP13 -TemplateEngine=TT };

    our @ISA = ( 'Gantry' );

    use Apps::AddressBook::Address;

    1;

Apps::AddressBook::Address

    package Apps::AddressBook::Address;

    use strict;

    use base 'Apps::AddressBook';

    use Apps::AddressBook::Model::address qw( $ADDRESS );

    use Gantry::Plugins::AutoCRUD;

    #-----------------------------------------------------------------
    # get_model_name( )
    #-----------------------------------------------------------------
    sub get_model_name {
        return $ADDRESS;
    }

    #-----------------------------------------------------------------
    # text_descr( )
    #-----------------------------------------------------------------
    sub text_descr     {
        return 'address';
    }

    #-----------------------------------------------------------------
    # $self->do_main(  )
    #-----------------------------------------------------------------
    sub do_main {
        my ( $self ) = @_;

        $self->stash->view->template( 'results.tt' );
        $self->stash->view->title( 'Address' );

        my $data = {
            headings       => [
                'Name',
                'Phone Number',
            ],
            header_options => [
                {
                    text => 'Add',
                    link => $self->location() . "/add",
                },
            ],
        };

        my @rows = $ADDRESS->retrieve_all_for_main_listing();

        foreach my $row ( @rows ) {
            my $id = $row->id;
            push(
                @{ $data->{rows} }, {
                    data => [
                        $row->name,
                        $row->phone,
                    ],
                    options => [
                        {
                            text => 'Edit',
                            link => $self->location() . "/edit/$id",
                        },
                        {
                            text => 'Delete',
                            link => $self->location() . "/delete/$id",
                        },
                    ],
                }
            );
        }

        $self->stash->view->data( $retval );
    } # END do_main

    #-----------------------------------------------------------------
    # $self->form( $row )
    #-----------------------------------------------------------------
    sub form {
        my ( $self, $row ) = @_;

        return {
            name       => 'address',
            row        => $row,
            legend     => $self->path_info =~ /edit/i ? 'Edit' : 'Add',
            fields     => [
                {
                    name  => 'name',
                    label => 'Name',
                    type  => 'text',
                },
                #...
            ],
        }
    } # END of form

    1;

Apps::AddressBook::Model::address

    package Apps::AddressBook::Model::address;
    use strict; use warnings;

    use base 'Gantry::Utils::CDBI', 'Exporter';

    our $ADDRESS = 'Apps::AddressBook::Model::address';

    our @EXPORT_OK = ( '$ADDRESS' );

    Apps::AddressBook::Model::address->table   ( 'address'     );
    Apps::AddressBook::Model::address->sequence( 'address_seq' );
    Apps::AddressBook::Model::address->columns ( Primary   => qw/ id / );

    Apps::AddressBook::Model::address->columns (
        All       => qw/
            id
            name
            street
            city
            state
            zip
            phone
        /
    );

    1;

=head1 Deploying the Application

After coding the above modules we only need to do two more things:
create the database and add our application to httpd.conf.

In postgres, you can merely say something like

    createdb address
    psql address -U apache < schema.sql

(supplying passwords as requested) where schema.sql is the one shown above
in L<Sample App Description>.

Assuming you are using mod_perl 1.3, you can add the following to your
httpd.conf:

    <Perl>
        #!/usr/bin/perl

        use lib '/home/me/Apps-AddressBook/lib';

        use AddressBook;
        use AddressBook::Address;
    </Perl>

    <Location />
        PerlSetVar dbconn dbi:Pg:dbname=address
        PerlSetVar dbuser apache
        PerlSetVar dbpass secret
        PerlSetVar template_wrapper wrapper.tt
        PerlSetVar root /home/me/Apps-AddressBook/html:/home/me/srcgantry/root
    </Location>

    <Location /address>
        SetHandler  perl-script
        PerlHandler Apps::AddressBook::Address
    </Location>

Adjust the dbconn, dbuser, and dbpass PerlSetVars for your database.  The root
needs to include the directory where wrapper.tt lives.  You can copy one
from the sample_wrapper.tt that ships with gantry (look in the directory
named root).

Now all that remains is to restart the server.

If you are using Gantry::Conf (which we prefer, but didn't discuss above),
you need to set one var:

    PerlSetVar GantryConfInstance addressbook

Then create a config file for the set vars shown above.  See
L<Gantry::Conf::Tutorial> for details.

If you are using CGI you need to make a script instead of adjusting apache
locations.  Here is ours:

    #!/usr/bin/perl

    use CGI::Carp qw( fatalsToBrowser );

    use lib '/home/me/Apps-AddressBook/lib';

    use Apps::AddressBook qw{ -Engine=CGI -TemplateEngine=TT };

    use Gantry::Engine::CGI;

    my $cgi = Gantry::Engine::CGI->new( {
        config => {
            dbconn => 'dbi:Pg:dbname=address',
            dbuser => 'apache',
            template_wrapper => 'wrapper.tt',
            root => '/home/me/Apps-AddressBook/html:',
                    '/home/me/srcgantry/root',
        },
        locations => {
            '/' => 'Apps::AddressBook',
            '/address' => 'Apps::AddressBook::Address',
        },
    } );

    $cgi->dispatch();

If you are using Gantry::Conf with CGI, use the single config hash key:

    my $cgi = Gantry::Engine::CGI->new( {
        config => {
            GantryConfInstance => 'address',
        }
        # locations as above
    } );

If you want to deploy the app as a stand alone server (most useful
during testing), change the above cgi script to this:

    #!/usr/bin/perl

    use Gantry::Server;

    use lib '/home/me/Apps-AddressBook/lib';

    use Apps::AddressBook qw{ -Engine=CGI -TemplateEngine=TT };
    use Gantry::Engine::CGI;

    my $cgi = Gantry::Engine::CGI->new( {
        config => {
            dbconn => 'dbi:Pg:dbname=address',
            dbuser => 'apache',
            template_wrapper => 'wrapper.tt',
            root => '/home/me/Apps-AddressBook/html:',
                    '/home/me/srcgantry/root',
        },
        locations => {
            '/' => 'Apps::AddressBook',
            '/address' => 'Apps::AddressBook::Address',
        },
    } );

    my $port = shift || 8080;
    my $server = Gantry::Server->new( $port );

    $server->set_engine_object( $cgi );
    $server->run();

That is, trade use CGI::Carp for use Gantry::Server and C<<$cgi->dispatch>>
for the last four lines shown above.  Running the script will start a
server on port 8080 (or whatever port was supplied on the command line).

=head1 Using Bigtop

Now I have a confession.  I never coded the example in the previous section.
I let Bigtop do it.

Bigtop is a code generator which can safely regenerate as thing change (like
the data model).  The bigtop script reads a Bigtop file to produce apps
like the one shown above.  There is a more detailed example in the tutorial
for Bigtop.

Bigtop uses its own little language to describe web applications.  The language
is designed for simplicity of structure.  There are basically only two
constructs: semi-colon terminated statements and brace delimited blocks.

[ Since this tutorial was writtern Bigtop has acquired tentmaker: a browser
delivered editor.  Using it saves typing.  See Bigtop::Docs::TentTut
for details. ]

To show how to use Bigtop, I'll walk through the above example again, this
time using bigtop.

First, type:

    bigtop --new Apps::AddressBook address

This will create a subdirectory under the current directory called
Apps-AddressBook and fill it with the basic structure of our application.

Now, change to the Apps-AddressBook directory and edit
docs/apps-addressbook.bigtop (feel free to rename the bigtop file).
(Alternatively, you could prepare the entire Bigtop file, then use

    bigtop --create file.bigtop all

The file for this example is in the examples directory of the Bigtop
distribution as address.bigtop and is above in the L<Complete Code Listings>
section.)

Immediately after initial generation is a good time to put the application
under your favorite revision control system.

XXX choose a fork: describe the bigtop file, or up the app, or use tentmaker
to customize

There are two required blocks in a bigtop file: config and app.  The config
block always comes first.  Let's see what goes in it.  As in the
the L<Hand-writing the Sample App> section above, I'll show the
Bigtop code a bit at a time with commentary interspersed.  Then,
after some user suggested revisions, I'll show the whole file all in
one piece in L<Complete Bigtop Code Listing>.

=head2 config

The config block allows you to specify the engine (like mod_perl 1.3) and
the template engine (like Template Toolkit) of the application.  Do this
with statements:

    config {
        engine          MP13;
        template_engine TT;

There are other engines, notably: CGI and MP20 for mod_perl 2.0.
If you don't want Template Toolkit, you can choose 'Default' as
the template engine.  Then you are on your own.

The rest of the config section has a list of the things you want to generate
and who should do the generating.

        Init            Std           {}

Init is only really useful when you create a new application, so the
--new option flags it with no_gen, like this:

        Init            Std           { no_gen 1; }

All of the other backends also respect the no_gen statement.

Once you build the first time, you probably want to set no_gen on Init,
since it is responsible for making things like Build.PL and the Changes
file, which we don't want to overwrite.

        SQL             Postgres      {}

SQL is responsible for making a file of sql statements which can build
the database (like schema.sql shown in L<Sample App Description>).  Here
we will ensure Postgres syntax.

The other backends are similar.

        HttpdConf       Gantry        {}

This generates the necessary bits for use in an Include statement in
httpd.conf.

        Control         Gantry        {}

This generates the controllers for the app, like Apps::AddressBook::Address.

        Model           GantryCDBI    {}

Generates the model class for the address table:
Apps::AddressBook::Model::address.

        SiteLook        GantryDefault {
            gantry_wrapper `/path/to/sample_wrapper.tt`;
        }
    }

Generates wrapper.tt.  Note that Bigtop::SiteLook::GantryDefault expects
a gantry_wrapper statement with a path to the sample wrapper that ships
with gantry.  Some backends understand other statements, see their docs.

That's all there is to the config block.

=head2 app

    app Apps::AddressBook {
        #...
    }

Most of the description is in the app block.  The block has a name which
becomes the name of the base controller module.  It usually corresponds to
the directory where the app is built (Apps::AddressBook usually lives in
Apps-AddressBook).

For our simple app, there are two statements in the app block and three
sub-blocks.  Folded in vim it looks like this:

    app Apps::AddressBook {
        authors `Phil Crow`;
        email   `philcrow2000@yahoo.com`;
    +--- 8 lines: config {------------------------------------------------
        sequence address_seq        {}
    +--- 34 lines: table    address {----------------------------------------
    +--- 18 lines: controller Address {--------------------------------------
    }

The two statements are the author and the email contact for him (me).
The email statement is optional, but if you want to use Module::Build's
Build.PL, you should include authors (otherwise you can't ./Build dist).

The four blocks are:

=over 4

=item config

listing configuration variables and their values

=item sequence

defining an SQL sequence named address_seq

=item table

defining an SQL table named address, its Model, and how its columns look
on-screen

=item controller

defining the controller named Apps::AddressBook::Address

=back

Details follow.

=head3 config

There are several config parameters needed to make the app work, as we saw in
the hand written section above.  Here we specify these in a block

    app Apps::AddressBook {
        #...
        config {
            dbconn    `dbi:Pg:dbname=address`          => no_accessor;
            dbuser    apache                           => no_accessor;
            dbpass    not_telling                      => no_accessor;
            template_wrapper `wrapper.tt`              => no_accessor;
            root      `/home/me/Apps-Address/html:/home/me/srcgantry/root`
                                                       => no_accessor;
        }

Using the no_accessor option prevents bigtop from making an accessor
and a statement in the init method for the variable.
For the variables shown here, those accessors would be the same as the
ones provided by Gantry.pm, so we don't need them.

=head3 sequence

Normally, we use a sequence for each table.  This allows for automatic
primary key generation.  This block defines the sequence for the address table:

    sequence address_seq {}

Note that the block is empty.  In the future you might be able to specify
min and max values, etc.  For now, leave it empty.

=head3 table

Now we come to the interesting parts.  First, we define the table.  Inside
its block we specify the name of its sequence and include a block for
each of its columns.

    table address {
        sequence address_seq;
        field id { is int4, primary_key, assign_by_sequence; }

The sequence must be previously defined.  The id field will be the
automatically generated primary key of the table.  It has only one
statement: is.  Normally the is statement for a field simply gives the
SQL type of the field (like int4 or varchar).  Here other attributes
are added.  Namely, it is marked as a primary key (this affects both
the SQL and Model) which is assigned from the sequence.  You can
abbreviate C<assign_by_sequence> as C<auto>.

The other fields have simpler is statements, but use additional statements.

        field name {
            is             varchar;
            label          Name;
            html_form_type text;
        }

The label is what the user sees when the field is on-screen.  This is
a table column label and the label next the input box on the add/edit form.
The html_form_type text yields an input element on the form of type text.
Not all types are supported by the Gantry templates, but bigtop doesn't care.
Give it whatever you like.  Gantry understands text, textarea, and select
(which it interprets as 'pick one item from a drop down menu').

All of the other fields are extremely similar -- see
L<Complete Bigtop Code Listing>.

They are called fields instead of columns to remind you that they
appear in many places, not just in the database table.

=head3 controller

Usually, each controller works with one table.  Once generation is complete,
you can safely add additional tables' models to the controller.  But, many
times the standard one-table/one-controller paradigm is sufficient,
as in the case of the address book:

    controller Address {
        controls_table       address;
        rel_location         address;
        uses                 Gantry::Plugins::AutoCRUD;
        text_description     `address`;
        #... method blocks
    }

There are many statements for use in controller blocks, four are shown here.

=over 4

=item controls_table

must be a table defined in the bigtop file

=item rel_location

the tail of the controller's Location url

=item uses

a comma separated list of modules used by the controller.  You could
also declare the controller as being type AutoCRUD and leave
Gantry::Plugins::AutoCRUD out of the uses list:

            controller Address is AutoCRUD {
                # as before with no uses statement
            }

=item text_description

used by AutoCRUD as discussed in the L<Hand-writing the Sample App>
section above

=back

Recall that for AutoCRUD to work we need to define two methods: do_main
and form.  These are represented by method subblocks in the controller block.

Each method is declared like this:

    method name is type { ... }

In our case the names will be do_main and form.  Their types will be
main_listing for do_main and AutoCRUD_form for form.

    method do_main is main_listing {
        title            `Address`;
        cols             name, phone;
        header_options   Add;
        row_options      Edit, Delete;
    }

The main listing has a browser title 'Address'.  Note that bigtop uses
backticks for quoting.  This leaves regular single and double quotes
for the normal Perl meanings.  I presume that web apps are exceedingly
unlikely to use backticks for shelling out.  If they ever did, it would
be in hand written code, not generated code.

The cols are the columns that will appear in the main listing table.
header_options appear at the right side of the heading strip while
row_options appear at the right side of each row.

    method form is AutoCRUD_form {
        form_name        address;
        all_fields_but   id;
        extra_keys
            legend     => `$self->path_info =~ /edit/i ? 'Edit' : 'Add'`;
    }

The form name becomes the name attribute of the form.  We use
it to support our legacy calendar popups.

You can either list fields you want to include on your form, or list
the fields you don't want with all_fields_but.

Extra keys go directly into the hash reference returned by the form method.
Ours puts Edit or Add into the fieldset legend.

=head2 Generating with bigtop

There are 80 lines in the example shown above.  Once you have those
typed in, you can generate like this:

    bigtop --create address.bigtop all

This will create the Apps-AddressBook subdirectory of the current directory and
all of the pieces described above.  You can then use the application after
installing it as described in the Deploying the Application section above.

Here is a complete list of what you get (with directory levels shown by
indentation):

 Apps-AddressBook/ - a directory where everything in the app lives
    Build.PL
    Changes        ready for use
    MANIFEST       complete as of the initial generation
    MANIFEST.SKIP
    README         in need of heavy editing
    docs/
       address.bigtop  - the original bigtop file
       httpd.conf      - an excerpt ready for inclusion in httpd.conf
                         for your mod_perl enabled apache
       schema.postgres - ready for use with psql
    html/
       wrapper.tt     - a simple site look
    lib/
       Apps/
          AddressBook.pm - base module for the app
          AddressBook/
             Address.pm - controller stub for the address table
                GEN/
                   Address.pm - generated code for Address.pm above
                Model/
                   address.pm - model stub for the address table
                   GEN/
                      address.pm - generated code for address.pm above
    t/
       01_use.t - tests whether each controller compiles

Note that there are more modules than in the hand written version.  This
allows you to change the data model and regenerate without fear of losing
hand coded changes.  So, AddressBook.pm, AddressBook::Address, and
AddressBook::Model::address are stubs providing a place for you to add
your customized code as needed; while AddressBook::GEN::Address and
AddressBook::Model::GEN::address are generated each time you run
bigtop.  If you need to do something other than what the generated code does, 
simply redefine the behavior in the non-generated code stubs and that will be
used. Do not edit the GEN modules, instead only add code to the stubs as
needed.

=head2 Revisions

As soon as I told my wife that I had the above app running, she offered
helpful suggestions in case she decided to use it.  First, the address
fields should be optional, since she doesn't always know where people live.
Second, she would like to add email addresses, since for some people that
is all she has.  Finally, and for our purposes more interestingly, she
once tracked birthdays in the back of the book.  While that requires
a bit too much effort, and we too stingy to send gifts, it would be
a nice addition, especially as nieces and nephews keep appearing with
some frequency.

The joy of bigtop is that revisions like these are fairly easily made.
In each case, we will: (1) modify the bigtop file and (2) regenerate.
Those two steps are often enough by themselves.  But, as before, there
may be some code we actually have to write.

The final version of the bigtop file is shown below.  It is also in
the Bigtop distribution's example directory as adress2.bigtop.

=head3 Making things optional

To mark the street, city, state, and zip as optional, we just need
to add a statement to their blocks:

    field street {
        is                 varchar;
        label              Street;
        html_form_type     text;
        html_form_optional 1;
    }

Setting html_form_optional to any true value (like 1 shown here), tells
the AutoCRUD scheme in Gantry to instruct Data::FormValidator
that the field is optional.  Users will not be required to supply it.
The other address fields also receive this treatment.

=head3 Constraining things

No data in the sample address book is validated (because Lisa has
too many friends and relatives living in too many places for meaningful
validation).

But, if you want validation, you can include it like so:

    field zip {
        is    varchar;
        label Zip;
        html_form_type text;
        html_form_optional 1;
        html_form_constraint `qr{^\d{5}$}`;
    }

The constraint could be a valid Perl regex.  You could also call a sub which
returns a regex.  If you include a uses statement in your controller like
this:

    uses Data::FormValidator::Constraints => `qw(:closures)`;

You can set the constraint like so:

        html_form_constraint `zip_or_postcode()`;

See perldoc Data::FormValidator::Constraints for details of the closures
available.  All of them return a regex suitable for use as shown.

=head3 Email address field

It is particularly easy to add a new field to the address table:

    field email {
        is                 varchar;
        label              `Email Address`;
        html_form_type     text;
        html_form_optional 1;
    }

Note that I put the label for this field in backquotes, since its name
contains a space.

We don't have to change the Address controller block, because the
only thing affected is the form.  We already specified that the form
should have all_fields_but id.  So, email will show up upon regeneration.

=head3 Birthday table

The most interesting change is adding birthdays.  In my mind, this leads
to a new table with this schema:

    CREATE SEQUENCE birth_seq;
    CREATE TABLE birth (
        id int4 PRIMARY KEY DEFAULT NEXTVAL( 'birth_seq' ),
        name varchar,
        family int4,
        birthday date
    );

To generate this sql, its model and controller we can add this
to our bigtop file (again, I'll show it a bit a time with commentary):

    sequence birth_seq {}
    table birth {
        sequence birth_seq;
        field id { is int4, primary_key, assign_by_sequence; }
        field name {
            is             varchar;
            label          Name;
            html_form_type text;
        }

This will the name of one person in a nuclear family.

        field family {
            is                int4;
            label             Family;
            html_form_type    select;
            refers_to         address;
        }

This field becomes a foreign key pointing to the address table, since it
uses the refers_to statement.  When the user enters a value for this
field, they must choose one family defined in the address table.

        field birthday {
            is                date;
            label             Birthday;
            html_form_type    date;
            date_select_text `Popup Calendar`;
        }
    }

I've chosen to store the actual date of birth (which leads to recording
women's ages, shame on me).  This is to show how date selection works
smoothly for your users.  There are three steps to this process.  The
first one is shown here: use the date_select_text statement.  Its value
becomes the link text the user clicks to popup the calendar selection
mini-window.  See, the controller below for the other two steps.

    controller Birth {
        controls_table   birth;
        rel_location     birthday;
        uses             Gantry::Plugins::AutoCRUD,
                         Gantry::Plugins::Calendar;

Step two in easy dates is to use Gantry::Plugins::Calendar which provides
javascript code generation routines.

        text_description `birthday`;
        page_link_label  Birthdays;

This page will show up in site navigation with its page_link_label

        method do_main is main_listing {
            title            `Birthday`;
            cols             name, family, birthday;
            header_options   Add;
            row_options      Edit, Delete;
        }

The main listing is just like the one for the address table, except for
the names of the displayed fields.

        method form is AutoCRUD_form {
            form_name        birthday_form;
            all_fields_but   id;
            extra_keys
                javascript => `$self->calendar_month_js( 'birthday_form' )`,
                legend     => `$self->path_info =~ /edit/i ? 'Edit' : 'Add'`;
        }
    }

Now the name of the form becomes important.  The calendar_month_js
method (mixed in by Gantry::Plugins::Calendar) generates the javascript
for the popup and its callback, which populates the date fields.
Note that we don't tell it which fields to handle.  It will work on
all fields that have date_select_text statements.

Once these changes are made, we can regenerate the application:

    bigtop docs/address.bigtop all

Execute this command while in the build directory (the one with the Changes
file in it).

=head2 Complete Bigtop Code Listing

 config {
    engine          MP13;
    template_engine TT;
    Init            Std           {}
    SQL             Postgres      {}
    HttpdConf       Gantry        {}
    Control         Gantry        {}
    Model           GantryCDBI    {}
    SiteLook        GantryDefault {
        gantry_wrapper `/home/pcrow/srcgantry/root/sample_wrapper.tt`;
    }
 }
 app Apps::AddressBook {
    authors `Phil Crow`;
    email   `philcrow2000@yahoo.com`;
    config {
        dbconn    `dbi:Pg:dbname=address`          => no_accessor;
        dbuser    apache                           => no_accessor;
        template_wrapper `wrapper.tt`              => no_accessor;
        root      `/home/pcrow/Bigtop/examples/Apps-AddressBook/html:/home/pcrow/srcgantry/root`
                                                   => no_accessor;
    }
    sequence address_seq        {}
    table    address {
        sequence address_seq;
        foreign_display `%name`;
        field id { is int4, primary_key, assign_by_sequence; }
        field name {
            is             varchar;
            label          Name;
            html_form_type text;
        }
        field street {
            is             varchar;
            label          Street;
            html_form_type text;
            html_form_optional 1;
        }
        field city {
            is             varchar;
            label          City;
            html_form_type text;
            html_form_optional 1;
        }
        field state {
            is             varchar;
            label          State;
            html_form_type text;
            html_form_optional 1;
        }
        field zip {
            is             varchar;
            label          Zip;
            html_form_type text;
            html_form_optional 1;
        }
        field phone {
            is             varchar;
            label          Number;
            html_form_type text;
        }
        field email {
            is                 varchar;
            label              `Email Address`;
            html_form_type     text;
            html_form_optional 1;
        }
    }
    sequence birth_seq {}
    table birth {
        sequence birth_seq;
        field id { is int4, primary_key, assign_by_sequence; }
        field name {
            is             varchar;
            label          Name;
            html_form_type text;
        }
        field family {
            is                int4;
            label             Family;
            html_form_type    select;
            refers_to         address;
        }
        field birthday {
            is                date;
            label             Birthday;
            html_form_type    date;
            date_select_text `Popup Calendar`;
        }
    }
    controller Address {
        controls_table   address;
        rel_location     address;
        uses             Gantry::Plugins::AutoCRUD;
        text_description `address`;
        method do_main is main_listing {
            title            `Address`;
            cols             name, phone;
            header_options   Add;
            row_options      Edit, Delete;
        }
        method form is AutoCRUD_form {
            form_name        address;
            all_fields_but   id;
            extra_keys
                legend     => `$self->path_info =~ /edit/i ? 'Edit' : 'Add'`;
        }
    }
    controller Birth {
        controls_table   birth;
        rel_location     birthday;
        uses             Gantry::Plugins::AutoCRUD,
                         Gantry::Plugins::Calendar;
        text_description `birthday`;
        page_link_label  Birthdays;
        method do_main is main_listing {
            title            `Birthday`;
            cols             name, family, birthday;
            header_options   Add;
            row_options      Edit, Delete;
        }
        method form is AutoCRUD_form {
            form_name        birthday_form;
            all_fields_but   id;
            extra_keys
                javascript => `$self->calendar_month_js( 'birthday_form' )`,
                legend     => `$self->path_info =~ /edit/i ? 'Edit' : 'Add'`;
        }
    }
 }

=head1 Summary

In this document we have seen how a simple Gantry app can be written
and deployed.  While building a simple app with bigtop can take just
a few minutes, interesting parts can be fleshed out as needed.  Our
goal is to provide a framework that automates the 50-80% of most apps
which is repetitive, allowing us to focus our time on the more interesting
bits that vary from app to app.

If you want to see a more realistic app, see Bigtop::Docs::Tutorial
which builds a basic freelancer's billing app.

There are other documents you might also want to read.

=over 4

=item Gantry::Docs::FAQ

categorized questions and answers explaining how to do common tasks

=item Gantry::Docs::About

marketing document listing the features of Gantry and telling its history

=back

The modules have their own docs which is where would be gantry developers
should look for more information.

=head1 Author

Phil Crow <philcrow2000@yahoo.com>

=head1 Copyright and License

Copyright (c) 2006, Phil Crow.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
