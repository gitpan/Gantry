package Gantry::Plugins::CRUD;

use strict;
use Carp;
use Data::FormValidator;

use Gantry::Utils::CRUDHelp qw( clean_dates clean_params form_profile );

#-----------------------------------------------------------
# Constructor
#-----------------------------------------------------------

sub new {
    my $class     = shift;
    my $callbacks = { @_ };

    unless ( defined $callbacks->{template} ) {
        $callbacks->{template} = 'form.tt';
    }

    return bless $callbacks, $class;
}

#-----------------------------------------------------------
# Accessors, so we don't misspell hash keys
#-----------------------------------------------------------

sub add_action {
    my $self = shift;

    if ( defined $self->{add_action} ) {
        return $self->{add_action};
    }
    else {
        croak 'add_action not defined or misspelled';
    }
}

sub edit_action {
    my $self = shift;

    if ( defined $self->{edit_action} ) {
        return $self->{edit_action}
    }
    else {
        croak 'edit_action not defined or misspelled';
    }
}

sub delete_action {
    my $self = shift;

    if ( defined $self->{delete_action} ) {
        return $self->{delete_action}
    }
    else {
        croak 'delete_action not defined or misspelled';
    }
}

sub form {
    my $self = shift;

    if ( defined $self->{form} ) {
        return $self->{form}
    }
    else {
        croak 'form not defined or misspelled';
    }
}

sub redirect {
    my $self = shift;
    return $self->{redirect}
}

sub template {
    my $self = shift;
    return $self->{template}
}

sub text_descr {
    my $self = shift;
    return $self->{text_descr}
}

sub use_clean_dates {
    my $self = shift;
    return $self->{use_clean_dates};
}

sub turn_off_clean_params {
    my $self = shift;
    return $self->{turn_off_clean_params};
}

#-----------------------------------------------------------
# Methods users call
#-----------------------------------------------------------

#-------------------------------------------------
# $self->add( $your_self, { put => 'your', data => 'here' } )
#-------------------------------------------------
sub add {
    my ( $self, $your_self, $data ) = @_;

    $your_self->stash->view->template( $self->template );
    $your_self->stash->view->title( 'Add ' . $self->text_descr );

    my $params   = $your_self->get_param_hash();

    # Redirect if user pressed 'Cancel'
    if ( $params->{cancel} ) {
        my $redirect = $self->_find_redirect(
            {
                gantry_site => $your_self,
                data        => $data,
                user_req    => 'add',
                action      => 'cancel',
            }
        );

        return $your_self->relocate( $redirect );
    }

    # get and hold the form description
    my $form = $self->form->( $your_self, $data );

    # Check form data
    my $show_form = 0;

    $show_form = 1 if ( keys %{ $params } == 0 );

    my $results = Data::FormValidator->check(
        $params,
        form_profile( $form->{fields} ),
    );

    $show_form = 1 if ( $results->has_invalid );
    $show_form = 1 if ( $results->has_missing );

    if ( $show_form ) {
        # order is important, first put in the form...
        $your_self->stash->view->form( $form );

        # ... then add error results
        if ( $your_self->method eq 'POST' ) {
            $your_self->stash->view->form->results( $results );
        }
    }
    else {
        # remove submit button entry
        delete $params->{submit};

        if ( $self->turn_off_clean_params ) {
            if ( $self->use_clean_dates ) {
                clean_dates( $params, $form->{ fields } );
            }
        }
        else {
            clean_params( $params, $form->{ fields } );
        }

        $self->add_action->( $your_self, $params, $data );

        # move along, we're all done here
        my $redirect = $self->_find_redirect(
            {
                gantry_site => $your_self,
                data        => $data,
                action      => 'submit',
                user_req    => 'add'
            }
        );
        return $your_self->relocate( $redirect );
    }
} # END: do_add

#-------------------------------------------------
# $self->edit( $your_self, { put => 'your', data => 'here' } );
#-------------------------------------------------
sub edit {
    my ( $self, $your_self, $data ) = @_;

    $your_self->stash->view->template( $self->template() );
    $your_self->stash->view->title( 'Edit ' . $self->text_descr() );

    my %params = $your_self->get_param_hash();

    # Redirect if 'Cancel'
    if ( $params{cancel} ) {
        my $redirect = $self->_find_redirect(
            {
                gantry_site => $your_self,
                data        => $data,
                action      => 'cancel',
                user_req    => 'edit',
            }
        );
        return $your_self->relocate( $redirect );
    }

    # get and hold the form description
    my $form = $self->form->( $your_self, $data );

    croak 'Your form callback gave me nothing' unless defined $form and $form;

    my $show_form = 0;

    $show_form = 1 if ( keys %params == 0 );

    # Check form data
    my $results = Data::FormValidator->check(
        \%params,
        form_profile( $form->{fields} ),
    );

    $show_form = 1 if ( $results->has_invalid );
    $show_form = 1 if ( $results->has_missing );

    # Form has errors
    if ( $show_form ) {
        # order matters, get form data first...
        $your_self->stash->view->form( $form );

        # ... then overlay with results
        if ( $your_self->method eq 'POST' ) {
            $your_self->stash->view->form->results( $results );
        }
    
    }
    # Form looks good, make update
    else {
        
        # remove submit button param
        delete $params{submit};

        if ( $self->turn_off_clean_params ) {
            if ( $self->use_clean_dates ) {
                clean_dates( \%params, $form->{ fields } );
            }
        }
        else {
            clean_params( \%params, $form->{ fields } );
        }

        $self->edit_action->( $your_self, \%params, $data );
        
        # all done, move along
        my $redirect = $self->_find_redirect(
            {
                gantry_site => $your_self,
                data        => $data,
                action      => 'submit',
                user_req    => 'edit'
            }
        );
        return $your_self->relocate( $redirect );
    }
} # END: do_edit

#-------------------------------------------------
# $self->delete( $your_self, $confirm, { other => 'data' } )
#-------------------------------------------------
sub delete {
    my ( $self, $your_self, $yes, $data ) = @_;

    $your_self->stash->view->template( 'delete.tt' );
    $your_self->stash->view->title( 'Delete' );

    if ( $your_self->params->{cancel} ) {
        my $redirect = $self->_find_redirect(
            {
                gantry_site => $your_self,
                data        => $data,
                action      => 'cancel',
                user_req    => 'delete'
            }
        );
        return $your_self->relocate( $redirect );
    }

    if ( ( defined $yes ) and ( $yes eq 'yes' ) ) {

        $self->delete_action->( $your_self, $data );

        # Move along, it's already dead
        my $redirect = $self->_find_redirect(
            {
                gantry_site => $your_self,
                data        => $data,
                action      => 'submit',
                user_req    => 'delete'
            }
        );
        return $your_self->relocate( $redirect );
    }
    else {
        $your_self->stash->view->form->message (
            'Delete ' . $self->text_descr() . '?'
        );
    }
}

#-----------------------------------------------------------
# Helpers
#-----------------------------------------------------------

sub _find_redirect {
    my ( $self, $args ) = @_;
    my $your_self = $args->{ gantry_site };
    my $data      = $args->{ data };
    my $action    = $args->{ action };
    my $user_req  = $args->{ user_req };

    my $retval;

    my $redirect_sub = $self->redirect;

    if ( $redirect_sub ) {
        $retval = $redirect_sub->( $your_self, $data, $action, $user_req );
    }
    else {
        $retval = $your_self->location();
    }

    return $retval;
}

1;

__END__

=head1 NAME 

Gantry::Plugins::CRUD - helper for somewhat interesting CRUD work

=head1 SYNOPSIS

    use Gantry::Plugins::CRUD;

    my $user_crud = Gantry::Plugins::CRUD->new(
        add_action      => \&user_insert,
        edit_action     => \&user_update,
        delete_action   => \&user_delete,
        form            => \&user_form,
        redirect        => \&redirect_function,
        template        => 'your.tt',  # defulats to form.tt
        text_descr      => 'database row description',
        use_clean_dates => 1,
        turn_off_clean_params => 1,
    );

    sub do_add {
        my ( $self ) = @_;
        $user_crud->add( $self, { data => \@_ } );
    }

    sub user_insert {
        my ( $self, $form_params, $data ) = @_;
        # $data is the value of data from do_add

        my $row = My::Model->create( $params );
        $row->dbi_commit();
    }

    # Similarly for do_delete

    sub do_delete {
        my ( $self, $doomed_id, $confirm ) = @_;
        $user_crud->delete( $self, $confirm, { id => $doomed_id } );
    }

    sub user_delete {
        my ( $self, $data ) = @_;

        my $doomed = My::Model->retrieve( $data->{id} );

        $doomed->delete;
        My::Model->dbi_commit;
    }

=head1 DESCRIPTION

This plugin helps you perform Create, Update, and Delete (commonly called
CRUD, except that R is retrieve which you still have to implement separately).

Warning: most plugins export methods into your package, this one does NOT.

Normally, you can use C<Gantry::Plugins::AutoCRUD> when you are controlling
a single table.  But, since its do_add, do_edit, and do_delete are genuine
template methods*, sometimes it is not enough.  For instance, if you need to
allow a regular user and an admin edit for the same database table, you need
two methods for each action (two for do_add, two for do_edit, and two
for do_delete).  This module can help.

* A template method has a series of steps.  At each step, it calls a method
via a hard coded name.

This module still does basically the same things that AutoCRUD does:

    redirect to listing page if user presses cancel
    if form parameters are valid:
        callback to action method
    else:
        if method is POST:
            add form validation errors
        (re)display form

=head1 METHODS

This is an object oriented only module (it doesn't export like the other
plugins).

=over 4

=item new

Constructs a new CRUD helper.  Pass in a list of the following callbacks
and config parameters:

=over 4

=item add_action (a code ref)

Called with:

    your self object
    hash of form parameters
    the data you passed to add

Called only when the form parameters are valid.
You should insert into the database and not die (unless the insert fails,
then feel free to die).  You don't need to change your location, but you may.

=item edit_action (a code ref)

Called with:

    your self object
    hash of form parameters
    the data you passed to edit

Called only when form parameters are valid.
You should update and not die (unless the update fails, then feel free
to die).  You don't need to change your location, but you may.

=item delete_action (a code ref)

Called with:

    your self object
    the data you passed to delete

Called only when the user has confirmed that a row should be deleted.
You should delete the corresponding row and not die (unless the delete
fails, then feel free to die).  You don't need to change your location,
but you may.

=item form (a code ref)

Called with:

    your self object
    the data you passed to add or edit

This needs to return just like the _form method required by
C<Gantry::Plugins::AutoCRUD>.  See its docs for details.
The only difference between these is that the AutoCRUD calls
_form with your self object and the row being edited (during editing)
whereas this method ALWAYS receives both your self object and the
data you supplied.

=item redirect (optional, defaults to $your_self->location() )

NOTE WELL: It is a bad idea to name your redirect callback 'redirect'.
That name is used internally in Gantry.pm.

Where you want to go whenever an action is complete.  If you need control
on a per action basis end your action callback with:

    $your_self->location( 'http://location.of/your/choice' );

Your redirect is called with your self object and the data you passed to
the add, edit, or delete method of this package.  This allows you complete
control, even on cancellation.

=item template (optional, defaults to form.tt)

The name of your form template.

=item text_descr

The text string used in the page titles and in the delete confirmation
message.

=item use_clean_dates (optional, defaults to false)

This is ignored unless you turn_off_clean_params, since it is redundant
when clean_params is in use.

Make this true if you want your dates cleaned immediately before your
add and edit callbacks are invoked.

Cleaning sets any false fields marked as dates in the form fields list
to undef.  This allows your ORM to correctly insert them as
nulls instead of trying to insert them as blank strings (which is fatal,
at least in PostgreSQL).

For this to work your form fields must have this key: C<<is => 'date'>>.

=item turn_off_clean_params (optional, defaults to false)

By default, right before an SQL insert or update, the params hash from the
form is passed through the clean_params routine which sets all non-boolean
fields which are false to undef.  This prevents SQL errors with ORMs that
can correctly translate blank strings into nulls for non-string types.

If you really don't want this routine, set turn_off_clean_params.  If you
turn it off, you can use_clean_dates, which only sets false dates to undef.

=back

Note that in all cases the submit key is removed from the params hash
by this module before any callback is made.

=item add

Call this in your do_add on a C<Gantry::Plugins::CRUD> instance:

    sub do_special_add {
        my $self = shift;
        $crud_obj->add( $self, { data => \@_ } );
    }

It will die unless you passed the following to the constructor:

        add_action
        form

You may also pass C<redirect> which must return a location suitable for passing
to $your_self->relocate.

=item edit

Call this in your do_edit on a C<Gantry::Plugins::CRUD> instance:

    sub do_special_edit {
        my $self = shift;
        my $id   = shift;
        my $row  = Data::Model->retrieve( $id );
        $crud_obj->edit( $self, { id => $id, row => $row } );
    }

It will die unless you passed the following to the constructor:

        edit_action
        form

You may also pass C<redirect> which must return a location suitable for passing
to $your_self->relocate.

=item delete

Call this in your do_delete on a C<Gantry::Plugins::CRUD> instance:

    sub do_special_delete {
        my $self    = shift;
        my $id      = shift;
        my $confirm = shift;
        $crud_obj->delete( $self, $confirm, { id => $id } );
    }

The C<$confirm> argument is yes if the delete should go ahead and anything
else otherwise.  This allows our standard practice of having delete
urls like this:

    http://somesite.example.com/item/delete/4

which leads to the confirmation form whose submit action is:

    http://somesite.example.com/item/delete/4/yes

which is taken as confirmation.

It will die unless you passed the following to the constructor:

        delete_action

You may also pass C<redirect> which must return a location suitable for passing
to $your_self->relocate.

=back

You can pick an choose which CRUD help you want from this module.  It is
designed to give you maximum flexibility, while doing the most repetative
things in a reasonable way.  It is perfectly good use of this module to
have only one method which calls edit.  On the other hand, you might have
two methods that call edit on two different instances, two methods
that call add on those same instances and a method that calls delete on
one of the instances.  Mix and match.

=head1 SEE ALSO

 Gantry::Plugins::AutoCRUD (for simpler situations)

 Gantry and the other Gantry::Plugins

=head1 LIMITATIONS

Currently only one redirection can be defined.  You can get more control
by ending your action callback like this:

    return $self->relocate( 'http://location.of/your/choice' );

=head1 AUTHOR

Phil Crow <philcrow2000@yahoo.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2005, Phil Crow

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
