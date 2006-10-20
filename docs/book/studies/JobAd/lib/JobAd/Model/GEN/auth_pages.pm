# NEVER EDIT this file.  It was generated and will be overwritten without
# notice upon regeneration of this application.  You have been warned.
package JobAd::Model::auth_pages;
use strict; use warnings;

__PACKAGE__->load_components( qw/ PK::Auto Core / );
__PACKAGE__->table( 'auth_pages' );
__PACKAGE__->add_columns( qw/
    id
    user_perm
    group_perm
    world_perm
    owner_id
    group_id
    url
    title
/ );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->belongs_to( owner_id => 'JobAd::Model::auth_users' );
__PACKAGE__->belongs_to( group_id => 'JobAd::Model::auth_groups' );
__PACKAGE__->base_model( 'JobAd::Model' );

sub get_foreign_display_fields {
    return [ qw( user_perm ) ];
}

sub get_foreign_tables {
    return qw(
        JobAd::Model::auth_users
        JobAd::Model::auth_groups
    );
}

sub foreign_display {
    my $self = shift;

    my $user_perm = $self->user_perm() || '';

    return "$user_perm";
}

sub table_name {
    return 'auth_pages';
}

1;

=head1 NAME

JobAd::Model::GEN::auth_pages - model for auth_pages table (generated part)

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
