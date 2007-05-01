package Gantry::Utils::Threeway;
use strict;

############################################################
# Functions                                                #
############################################################
sub new {
    my ( $class, $opt ) = @_;

    my $self = { options => $opt };
    bless( $self, $class );

    my @errors;
    foreach( qw/join_table primary_table secondary_table self/ ) {
        push( @errors, "$_ is not set properly" ) if ! $opt->{$_};
    }

    if ( scalar( @errors ) ) {
        die join( "\n", @errors );
    }
    
    # populate self with data from site
    return( $self );

} # end new

#-------------------------------------------------
# process()
#-------------------------------------------------
sub process { 
    my( $self ) = @_;

    my $gself = $self->{options}{self};

    my $join_table      = $self->{options}{join_table};
    my $primary_table   = $self->{options}{primary_table};
    my $secondary_table = $self->{options}{secondary_table};
    my $order_by        = $self->{options}{order_by} || 'id';
    my $legend          = $self->{options}{legend} || "Add ${secondary_table}s";

    my $sch   = $gself->get_schema();
    my %param = $gself->get_param_hash;

    # pull from the member table
    my $selected = $sch->resultset( $join_table )->search( 
        { $primary_table => $self->{options}{primary_id} }, { } 
    );

    my %selected;
    while ( my $r = $selected->next ) {
        $selected{$r->$secondary_table . ''} = $r->id;
    }
    
    if ( $gself->is_post() ) {

        if ( $param{cancel} ) {
            $gself->relocate( $gself->location );
            return;            
        }
        
        my $available = $sch->resultset( $secondary_table )->search( 
            {}, { order_by => $order_by } 
        );

        my %available;
        while ( my $r = $available->next ) {
            ++$available{$r->id . ''};
        }
                
        foreach my $k ( keys %param ) {
            next if $k !~ /^subscribe/;

            my @val = split( ':', $k );
            
            $sch->resultset( $join_table )->update_or_create(
                { 
                    $primary_table   => $self->{options}{primary_id}, 
                    $secondary_table => $val[1] }
            );
            
            # delete from available hash
            delete( $selected{$val[1]} );
    
        }

        my @remove;
        foreach my $k ( keys %selected ) {
            push( @remove, $selected{$k} );
        }

        if ( scalar( @remove ) > 0 ) {
            $sch->resultset( $join_table )->search( 
                id => \@remove 
            )->delete;
        }
        
        $gself->relocate( $gself->location );
        return;

    }   

    my $available = $sch->resultset( $secondary_table )->search( {}, {
        order_by => $order_by,
    } );
     
    $gself->stash->view->template( 'threeway.tt' );
    $gself->stash->view->form( { legend => $legend } );
    $gself->stash->view->data( { 
        available => $available, 
        selected => \%selected 
    } );

} # END process 

# EOF
1;

__END__

=head1 NAME 

Gantry::Utils::Threeway - Form processing util for a three-way join

=head1 SYNOPSIS

    sub do_something {

        my( $self, $blog_id ) = @_;

        my $threeway = Gantry::Utils::Threeway->new( { 
            self            => $self,
            primary_id      => $blog_id,
            primary_table   => 'blog',
            join_table      => 'blog_tag',
            legend          => 'Add Tags',
            orderby         => 'id',
            secondary_table => 'tag'        
        } );
    
        $threeway->process();
    
    }

=head1 DESCRIPTION

This module is a utillity to help process the three-way join tables.

=head1 METHODS 

=over 4

=item new

Standard constructor, call it first. 

Requires the following parameters

    self             # gantry site object
    primary_id       # the row id for which your adding the relationships to
    primary_table    # the primary table
    join_table       # the join table is where the relationship rows are stored
    secondary_table  # table in which your're relating to

Optional parameters

    legend        # form legend
    order_by      # sort list by this field
        
=item process()

preforms the CRUD like procedures for maintaining the three-way relationships. 

=back

=head1 SEE ALSO

Gantry(3)

=head1 LIMITATIONS 

This module depends on Gantry(3)

=head1 AUTHOR

Tim Keefer <tkeefer@gmail.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2005-7, Tim Keefer.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
