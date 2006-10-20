# NEVER EDIT this file.  It was generated and will be overwritten without
# notice upon regeneration of this application.  You have been warned.
package JobAd::Model::auth_groups;
use strict; use warnings;

__PACKAGE__->load_components( qw/ PK::Auto Core / );
__PACKAGE__->table( 'auth_groups' );
__PACKAGE__->add_columns( qw/
    id
    ident
    description
    name
/ );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->base_model( 'JobAd::Model' );

sub get_foreign_display_fields {
    return [ qw( ident ) ];
}

sub get_foreign_tables {
    return qw(
    );
}

sub foreign_display {
    my $self = shift;

    my $ident = $self->ident() || '';

    return "$ident";
}

sub table_name {
    return 'auth_groups';
}

1;

=head1 NAME

JobAd::Model::GEN::auth_groups - model for auth_groups table (generated part)

=head1 DESCRIPTION

This model inherits from Gantry::Utils::DBIxClass.
It was generated by Bigtop, and IS subject to regeneration.

=head1 METHODS

You may use all normal Gantry::Utils::DBIxClass methods and the
ones listed here:

=over 4

=item get_foreign_display_fields

=item get_foreign_tables

=item foreign_display

=item table_name

=back

=cut
