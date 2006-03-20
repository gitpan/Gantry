package Gantry::Docs::FAQ;

=head1 Name

Gantry::Docs::FAQ - Frequently asked questions and answers about gantry

=head1 Intro

This document is like a FAQ, except no one asked us these questions.
We made the list to collect our knowledge in one place before we forgot it.

The questions are:

=over 4

=item *

Install

=over 4

=item *

L<How do I install Gantry?>

=item *

L<How do I install Gantry on Shared Hosting?>

=back

=item *

Coding

=over 4

=item *

L<What is the smallest app I could write with Gantry?>

=item *

L<How do I turn off templating to dump raw text?>

=item *

L<How do I use gantry's AutoCRUD?>

=item *

L<What about retrieval?>

=item *

L<What if AutoCRUD won't work for me?>

=item *

L<What if AutoCRUD really won't work for me?>

=item *

L<Can I use AutoCRUD and/or CRUD if I wrote my own models?>

=item *

L<How do I control error page appearance?>

=item *

L<How can I let my users pick dates easily?>

=back

=item *

Deployment

=over 4

=item *

L<How do I deploy a gantry app under mod_perl?>

=item *

L<How do I deploy a gantry app under CGI?>

=item *

L<How do I deploy a gantry app under FastCGI?>

=item *

L<What is Gantry::Conf?>

=item *

L<How do I use Gantry::Conf under mod_perl?>

=item *

L<How do I use Gantry::Conf under CGI/FastCGI?>

=back

=item *

Appearance

=over 4

=item *

L<Where does Gantry look for style sheets, templates, etc.?>

=back

=item *

Authentication

=over 4

=item *

L<What tables do I need in my database for authentication?>

=item *

L<How do I add authentication to my gantry app?>

=item *

L<How do I add gantry authentication to my non-gantry app?>

=item *

L<How do I add gantry authentication to my static page location?>

=item *

L<How can I share my authentication database across multiple apps?>

=back

=item *

Scripts

=over 4

=item *

L<How can my cron (and other) scripts use an app's models?>

=back

=back

=head1 Install

=head2 How do I install Gantry?

Download the source, extract it, change to that directory and run 
the following commands:

=item perl Build.PL

=item ./Build test

=item ./Build install

=head2 How do I install Gantry on Shared Hosting?

Download the source, extract it, change to that directory and run
the following commands:

=item perl Build.PL

=item ./Build test

=item ./Build install --install_base=<path to your local perl modules>

=over 4

=item * 

Installing Dependancies:

If your hosting provider will not install the module Dependancies 
you can just install them from source. You probably will not have 
access to install into the system perl directories. 

=item Modules using Build.PL

=over 4

=item perl Build.PL

=item ./Build test

=item ./Build install --install_base=<path to local Perl modules>

=back

=item Modules using Makefile.PL

=over 4

=item perl Makefile.PL 

=item make test

=item make install DISTDIR=<path to local Perl modules>

=back

=back

=head1 Coding

=head2 What is the smallest app I could write with Gantry?

To see small Gantry apps consult Gantry::Docs::QuickStart and/or
Gantry::Docs::Tutorial.

=head2 How do I turn off templating to dump raw text?

You can choose the formatting of your choice as long as your choice is
Template Toolkit or no formatting.  To choose the latter,
when initially using Gantry (or an app which uses it)
specify -TemplateEngine=Default.

=head2 How do I use gantry's AutoCRUD?

Once you have a database and a Class::DBI descended model for it (or
one which responds to the same API), you can use gantry's AutoCRUD.  First,

    use Gantry::Plugins::AutoCRUD;

This is more a mixin than a plugin.  It exports do_add, do_edit, do_delete,
and form_name into your module.  The form_name method merely returns the
text 'form.tt' which is the name of the default template for add/edit forms.
If you want a different template, don't import form_name, instead implement
your own form_name method.

For the exported CRUD methods to work you must implement three methods:

=over 4

=item get_model_name

Returns the package name of the model for your table.

=item text_descr

Returns a one- or two-word description of the items in the table.

=item form

Receives the site object and, during editing, the row object the user is
modifying.  Returns a hash reference suitable for direct use as the view.form
of form.tt.  See the comments in form.tt for a list of what you can
put in the hash.  (If your template is different consult it.)

=back

=head2 What about retrieval?

Your model should provide convenient retrieval methods.  Gantry's
Gantry::Utils::CDBI inherits from CDBI::Sweet, so it responds to all
the standard Class::DBI methods (with the Sweet additions.
Gantry::Utils::CDBI also has the poorly named
retrieve_all_for_main_listing to return all rows in a pleasant order.

=head2 What if AutoCRUD won't work for me?

Gantry::Plugins::AutoCRUD is somewhat rigid, but not as rigid as the
above example makes it seem.  For instance, suppose the above won't
work because you need to specify a creation time for every add.
AutoCRUD provides hooks.

These are the hooks:

=over 4

=item add_pre_action

Called after form data validation and before the new row is inserted
into the database.  It receives a hash reference of form parameters.
This is a good time to add things like creation dates:

    sub add_pre_action {
        my ( $params ) = @_;

        $params->{ created } = 'now';
    }

=item add_post_action

Called after row insertion.  It receives the new row.  This is a good
time to log changes or send email to interested (or uninterested) parties.

=item edit_pre_action

Called after form data validation and before changing the data in the
database.  It receives the row object which is about to be changed and a
hash reference of form parameters which are about to become the new
values for that row.  Make your changes in the params hash.  For example,
you could insert a new key:

    sub edit_pre_action {
        my ( $row, $params_hash_ref ) = @_;

        $params_hash_ref{ modified } = 'now';
    }

=item edit_post_action

Called after changing the data in the database with the row object as
amended.  Do whatever you like.  A common pattern is to pair pre and post
actions.  For instance, we have an application which sends email only if
the status field of a row has changed.  Its edit hook methods
look roughly like this:

    sub old_status { # an accessor
        my ( $self, $old_status ) = @_;

        if ( $old_status ) {
            $self->{__OLD_STATUS__} = $old_status;
        }
        return $self->{__OLD_STATUS__};
    }
    sub edit_pre_action { # sets the old_status attribute
        my ( $row, $params_ref ) = @_;

        $self->old_status( $row->status );
    }
    sub edit_post_action { # sends mail if the status changed
        my ( $self, $row ) = @_;

        my $old_status = $self->old_status();
        my $new_status = $row->status;

        if ( $old_status != $new_status ) {
            $self->send_status_mail( $row );
        }
    }

=item delete_pre_action

Called after user confirmation and immediately before the doomed row
is removed from the database.  It receives the row object which is
about to meet its maker.  This is a good place to log its demise
in some other table or die if something has gone awry.

=item delete_post_action

Called immediately after the row has been removed from the database
(commit has already been called).  It receives the id number of the
deceased.  This might be a good place to log the event.

=item get_relocation

Called with the current action (add, edit, or delete) and either submit
or cancel (depending on which button the user pressed).  Return the
url where you want the user to be redirected.

=item get_submit_loc

Ignored if get_relocation is defined.

Called with the current action (add, edit, or delete) and the string 'submit'.
Return the url where you want the user to be redirected.

=item get_cancel_loc

Ignored if get_relocation is defined.

Called with the current action (add, edit, or delete) and the string 'cancel'.
Return the url where you want the user to be redirected.

=back

You may implement as many of these methods as you like in your controller.
Any that are not implemented are simply not called.

=head2 What if AutoCRUD really won't work for me?

While the answer to the last question shows a certain amount of flexibility
in the AutoCRUD scheme, sometimes it just isn't enough.  If you want control,
but don't want to worry with the basics of displaying the form, validating
results, etc. Gantry::Plugins::CRUD is for you.

To have a concrete example, suppose my controller posts comments on a
blog entry, but only if the user is logged in.

Unlike its AutoCRUD counterpart, Gantry::Plugins::CRUD does not export
anything.  Instead it is an object oriented helper.  Here's how it works.
First, use it:

    use Gantry::Plugins::CRUD;

Then make an instance of it, being explicit about what it should do when:

    my $comment_crud = Gantry::Plugins::CRUD->new(
        add_action      => \&add_comment,
        edit_action     => \&edit_comment,
        delete_action   => \&delete_comment,
        form            => \&my_form,
        template        => 'comment_form.tt',
        text_descr      => 'comment',
    );

There are other keys you may use -- see the perldoc for Gantry::Plugins::CRUD
for details.

We'll look at the actions in some detail below.  First, let's examine
the other hash keys here.

The form method must return a single value (usually a hash reference), which
will go to the template that shows the form on the screen.
The text_descr is used when asking the user to confirm a deletion.

All that remains is to implement your own do_ methods to catch the CRUD
requests for your controller.

    do_add {
        my ( $self, $blog_id ) = @_;

        unless ( $self->is_logged_in ) {
            die 'You must log in to post a comment'
        }

        $comment_crud->add( $self, { blog_id = $blog_id } );
    }

If the security check passes, the CRUD plugin's add method will take care of
showing the comment form and validating the data on it.  Once it is
satisfied that the comment is valid, it will call add_comment (or
whatever you registered as the add_action when you called the constructor).
Here's an example:

    sub add_comment {
        my ( $self, $params, $data ) = @_;

        $params->{ blog_id } = $data->{ blog_id };
        $params->{ user_id } = $self->user_id;
        $params->{ created } = 'now';
        $params->{ body    } = $self->sanitize_body( $params->{ body } );

        my $new_row = Model::comments->create( $params );
        $new_row->dbi_commit;

        $self->send_spam( $data->{ blog_id }, $new_row );
    }

You are completely responsible for updating the database in the add_action.
A good model helps with this.

The other actions work similarly.  Note that there is no need to be completely
honest with the names.  It would a good use of Gantry::Plugins::CRUD to
implement do_delete so that it marked rows as invisible rather than deleting
them.  That wouldn't be possible with AutoCRUD.

As a final note, it is not necessary to define all the options for a
Gantry::Plugins::CRUD object.  It is fine to have only delete_action
and the keys it needs.  You may also have different objects for add,
edit, and/or delete.  This gives an easy way for add and edit to use
different forms, for example.

=head2 Can I use AutoCRUD and/or CRUD if I wrote my own models?

This is really two questions.  First, 'Can I use AutoCRUD with hand
written models?'  The answer is: Yes, so long as your model responds
to dbi_commit, create and retrieve calls, the objects returned by
retrieve respond to delete, and -- when your form is used for
editing -- it expects a row object returned by your retrieve.

Second, 'Can I use CRUD if I wrote my own models?'  The answer is: Yes.
For CRUD none of the above restrictions apply since it works even if
there is no model.

=head2 How do I control error page appearance?

When something in Gantry dies, the main handler traps the error and
calls custom_error on the site object to generate the error page.
Simply implement your own custom_error to change how the error output
appears to your users.  Note that it is often useful to change from
a developer-friendly version to a user-friendly version as you move
to production.

The custom_error method is invoked on the site object.  It receives
an array of error output lines.

=head2 How can I let my users pick dates easily?

Date entry is controlled by form.tt.  To make it work you need to do
two things, both of them in them in your form method:

=over 4

=item 1.

Name your form by including this key in the returned hash:

    name => 'your_name',

=item 2.

Add a javascript key to the returned hash:

    javascript => $self->calendar_month_js( 'your_name' ),

your_name must match the name from step 1.

=item 3.

Add a date_select_text key to the hash of each date field:

    {
        date_select_text => 'Popup Calendar',
        # ...
    }

See Bigtop::Docs::Tutorial for how to make these steps happen from bigtop
files.

=back

=head1 Deployment

=head2 How do I deploy a gantry app under mod_perl?

There are three steps to placing most gantry apps under mod_perl.

=over 4

=item 1

Include PerlSetVar statements for configuration information in the
root Location block for the app:

    <Location />
        PerlSetVar dbconn dbi:Pg:dbname=mydb
        PerlSetVar dbuser unknown
        PerlSetVar dbpass none_of_your_business
        PerlSetVar root   /home/you/templates:/home/gantry/root

        SetHandler  perl-script
        PerlHandler Apps::Malcolm
    </Location>

You probably need more set vars, but that should be enough to show
you where they go.

=item 2

Modify your httpd.conf to include a Location for each controller in your app:

    <Location /sub>
        SetHandler  perl-script
        PerlHandler App::Base::Module::Sub
    </Location>

    <Location /sub2>
        SetHandler  perl-script
        PerlHandler App::Base::Module::SubOther
    </Location>

    <Location /sub/system>
        SetHandler  perl-script
        PerlHandler App::Base::Module::Sub::System
    </Location>

=item 3

Use gantry in a way that loads one of the mod_perl engines.  There are
multiple ways to do this.  All of them involve a use statement like this:

    use Gantry qw{ -Engine=MP13 -TemplateEngine=TT };

(Replace MP13 with MP20 if you use mod_perl 2.)

This statement can go in a <Perl> block above the root location.  It
could also go in your startup.pl.  Finally, you could put it in the base
module's .pm file.  It makes no real difference on a single environment
system.  The first two methods are better if you might also deploy the app
in a different environment (since then the app would never know which
environment it was in, and so no code change would be needed to
move environments).

=back

=head2 How do I deploy a gantry app under CGI?

Create an executable file in a cgi-bin directory like this one:

    #!/usr/bin/perl
    use strict;

    use App::Base::Module qw{ -Engine=CGI -TemplateEngine=TT };

    my $cgi = Gantry::Engine::CGI->new(
        {
            locations => {
                '/'           => 'App::Base::Module',
                '/sub'        => 'App::Base::Module::Sub',
                '/sub2'       => 'App::Base::Module::SubOther',
                '/sub/system' => 'App::Base::Module::Sub::System',
            }
            config {
                dbconn => 'dbi:Pg:dbname=mydb',
                dbuser => 'unknown',
                dbpass => 'none_of_your_business',
                root   => '/home/you/templates:/home/gantry/root',
            }
        }
    );

    $cgi->dispatch();

Adjust the config parameters to fit your app.  Use as many locations
as you like.

=head2 How do I deploy a gantry app under FastCGI?

FastCGI requires only a couple of slight changes to the above CGI script.

=over 4

=item *

At the top:

    use FCGI;

=item *

Wrap the dispatch statement like this:

    my $request = FCGI::Request();

    while ( $request->Accept() >= 0 ) {
        $cgi->dispatch();
    }

=back

=head2 What is Gantry::Conf?

Gantry::Conf provides a complete configuration scheme for both web
and traditional programs.  It allows you to share configuration between
your web app and its cron scripts.  It lets you run multiple instances
of the same app in the same apache instance with separate configurations.
It also lets you share configuration between apps even if they run on different
servers (by allowing for http or https access to a single conf file).

See Gantry::Conf::Tutorial for how to set up your conf files among other
details.

=head2 How do I use Gantry::Conf under mod_perl?

To make Gantry::Conf work, you must tell it which instance you need to
configure.  In mod_perl do this by setting this variable at the root
location of your applications:

    PerlSetVar GantryConfInstance your_instance_name

If you are not using the default /etc/gantry.conf for Gantry::Conf's
configuration, set one additional variable:

    PerlSetVar GantryConfFile /full/path/to/your/conf.file

=head2 How do I use Gantry::Conf under CGI/FastCGI?

To make Gantry::Conf work, you must tell it which instance you need to
configure.  In CGI and FastCGI do this by setting this by setting this
key in the config hash passed to the Gantry::Engine::CGI constructor:

    GantryConfInstance => 'your_instance_name'

If you are not using the default /etc/gantry.conf for Gantry::Conf's
configuration, set one additional variable:

    GantryConfFile => '/full/path/to/your/conf.file'

=head1 Appearance

=head2 Where does Gantry look for style sheets, templates, etc.?

The answer depends somewhat on how you deploy the application.
Under CGI it looks in the config section of the hash you passed
to Gantry::Engine::CGI->new.  Under mod_perl it looks for PerlSetVar
statements.

In both cases the names it looks for are the same.  Here are the ones
Gantry.pm understands (these are highly integrated into the standard
templates):

=over 4

=item content_type

Used to generate the Content-type: header.  Defaults to text/html.

=item template

The default template to use for page rendering.  Usually overridden
by a do_* method.

=item template_default

(Ignored if template above is defined and no do_* method places a
template in the stash.)

The default template to use for page rendering.

=item template_wrapper

The Template Toolkit WRAPPER for the site.

=item template_disable

Set this flag to a true value to turn off template processing.

=item root

The template root (in the TT sense) for the app.

=item css_root

The absolute path to the css directory on your disk.

=item img_root

The absolute path to the image directory on your disk.

=item tmp_root

The absolute path to a tmp directory on your disk.

=item app_rootp

The root uri for your application.  Defaults to '' which is equivalent
to '/'.

=item css_rootp

The root uri for css files.  Try '/css'.  Then place your css files
in the css subdirectory of your document root.

=item img_rootp

The root uri for image files.

=item tmp_rootp

The root uri for tmp files.

=item editor_rootp

The root uri of the html editor for the application (so users can enter
html without worry on your part or theirs).

=back

=head1 Authentication

=head2 What tables do I need in my database for authentication?

Gantry uses four tables for its authentication system.  You can either
put these into your app's database, or store them in another database.
This allows you to share auth between multiple apps.

The schema for the tables is in the SCHEMA FOR AUTH TABLES section
of Gantry::Control.

=head2 How do I add authentication to my app?

Gantry provides integrated support for Apache's basic authentication.
First, you need to have a database for authentication or put the auth tables
into your app's database (see the previous question).

Then, you need to add the following Apache directives to the base location
for your app (or to the location at which auth should begin):

    AuthType Basic
    AuthName "Your Auth Realm Name"

    PerlSetVar auth_dbconn  "dbi:Pg:dbname=your_auth_db"
    PerlSetVar auth_dbuser  apache
    PerlSetVar auth_dbpass  super_secret

    PerlAuthenHandler Gantry::Control::C::Access
    PerlAuthenHandler Gantry::Control::C::Authen
    PerlAuthzHandler  Gantry::Control::C::Authz

You need to set auth_dbconn, auth_dbuser, and auth_dbpass even if your
auth tables are in your app's database.

Finally, add directives to the proper locations:

    require group NAME
    require valid-user

If you want to limit access by IP, set this perl var for the location:

    PerlSetVar auth_allow_ips   "172.168.2.41,172.168.2.182'

Note: if you are doing anything important, you should run it through ssh to
keep the sniffers from seeing your passwords.

=head2 How do I add gantry authentication to my non-gantry app?

You don't need a gantry app to use gantry's auth modules.  Simply follow
the instructions in the answer to the previous question.

=head2 How do I add gantry authentication to my static page location?

You don't even need an app to use gantry's auth modules.  Just do the
same thing you would do if you had an app.

=head2 How can I share my authentication database across multiple apps?

Two or more apps can share one auth database by setting their
auth_dbconn to the same connection string.  This does require a bit
of coordination in the auth_groups and auth_group_members tables.

=head1 Scripts

=head2 How can my cron (and other) scripts use an app's models?

For now, your script should use the provided helper:

    package Gantry::Utils::Helper::Script;

    Gantry::Utils::Helper::Script->set_conn_info(
        {
            dbconn => 'dbi:Pg:dbname=yourdb;host=127.0.0.1',
            dbuser => 'auser',
            dbpass => 'secret',
        }
    )

Change the methods as needed (to reflect your database names, user, and
password or to allow the main package to fill in the values from command
line args or config file info).  This works for all models which inherit
from Gantry::Utils::CDBI.

If any of your models inherit from Gantry::Utils::AuthCDBI, then
you must include auth_conn_info.

    Gantry::Utils::Helper::Script->auth_conn_info(
        {
            auth_dbconn => 'dbi:Pg:dbname=yourauthdb;host=127.0.0.1',
            auth_dbuser => 'auser',
            auth_dbpass => 'super_secret',
        }
    );

Note that some models which inherit from Gantry::Utils::CDBI might
have foreign keys pointing to other models which inherit from
Gantry::Utils::AuthCDBI.  In that case, even though you don't directly
see the need for auth, you do in fact need it.

=head1 Summary

If you have other questions, send them in.  Maybe some day this will be
a genuine FAQ.

=head1 Author

Phil Crow <philcrow2000@yahoo.com>

=head1 Copyright and License

Copyright (c) 2006, Phil Crow.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
