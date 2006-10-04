# NEVER EDIT this file.  It was generated and will be overwritten without
# notice upon regeneration of this application.  You have been warned.
package Gantry::Control::Model::GEN::auth_groups;
use strict; use warnings;

use base 'Gantry::Utils::Model::Auth';

use Carp;

sub get_table_name    { return 'auth_groups'; }

sub get_primary_col   { return 'id'; }

sub get_essential_cols {
    return 'id, name, description, ident';
}

sub get_primary_key {
    goto &id;
}

sub id {
    my $self  = shift;
    my $value = shift;

    if ( defined $value ) {
        return $self->set_id( $value );
    }

    return $self->get_id();
}

sub set_id {
    croak 'Can\'t change primary key of row';
}

sub get_id {
    my $self = shift;
    return $self->{id};
}

sub quote_id {
    return $_[1];
}

sub description {
    my $self  = shift;
    my $value = shift;

    if ( defined $value ) { return $self->set_description( $value ); }
    else                  { return $self->get_description();         }
}

sub set_description {
    my $self  = shift;
    my $value = shift;

    $self->{description} = $value;
    $self->{__DIRTY__}{description}++;

    return $value;
}

sub get_description {
    my $self = shift;

    return $self->{description};
}

sub quote_description {
    return ( defined $_[1] ) ? "'$_[1]'" : 'NULL';
}

sub ident {
    my $self  = shift;
    my $value = shift;

    if ( defined $value ) { return $self->set_ident( $value ); }
    else                  { return $self->get_ident();         }
}

sub set_ident {
    my $self  = shift;
    my $value = shift;

    $self->{ident} = $value;
    $self->{__DIRTY__}{ident}++;

    return $value;
}

sub get_ident {
    my $self = shift;

    return $self->{ident};
}

sub quote_ident {
    return ( defined $_[1] ) ? "'$_[1]'" : 'NULL';
}

sub name {
    my $self  = shift;
    my $value = shift;

    if ( defined $value ) { return $self->set_name( $value ); }
    else                  { return $self->get_name();         }
}

sub set_name {
    my $self  = shift;
    my $value = shift;

    $self->{name} = $value;
    $self->{__DIRTY__}{name}++;

    return $value;
}

sub get_name {
    my $self = shift;

    return $self->{name};
}

sub quote_name {
    return ( defined $_[1] ) ? "'$_[1]'" : 'NULL';
}

sub get_foreign_display_fields {
    return [ qw(  ) ];
}

sub get_foreign_tables {
    return qw(
    );
}

sub foreign_display {
    my $self = shift;

}

1;

=head1 NAME

Gantry::Control::Model::GEN::auth_groups - model for auth_groups table

=head1 METHODS

=over 4

=item description

=item foreign_display

=item get_description

=item get_essential_cols

=item get_foreign_display_fields

=item get_foreign_tables

=item get_id

=item get_ident

=item get_name

=item get_primary_col

=item get_primary_key

=item get_sequence_name

=item get_table_name

=item id

=item ident

=item name

=item quote_description

=item quote_id

=item quote_ident

=item quote_name

=item set_description

=item set_id

=item set_ident

=item set_name

=back

=head1 AUTHOR

Generated by Bigtop, please don't edit.

=cut