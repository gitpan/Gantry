package Gantry::Cache::FastMmap;

use strict;
use warnings;

use Gantry;
use Cache::FastMmap;

use base 'Exporter';
our @EXPORT = qw( 
    cache_del
    cache_get
    cache_set
    cache_init
    cache_handle
    cache_inited
    cache_expires
    cache_namespace
);

sub cache_init {
    my ($gobj) = @_;

    my $cache;
    my $num_pages = $gobj->fish_config('cache_pages') || '256';
    my $page_size = $gobj->fish_config('cache_pagesize') || '256k';
    my $expire_time = $gobj->fish_config('cache_expires') || '1h';
    my $share_file = $gobj->fish_config('cache_filename') || '/tmp/gantry.cache';

    eval {

        $cache = Cache::FastMmap->new(num_pages => $num_pages,
                                      page_size => $page_size,
                                      expire_time => $expire_time,
                                      share_file => $share_file);

    }; if ($@) {

        die('Unable to use - Gantry::Cache::FastMmap');

    }

    $cache->purge();
    $gobj->cache_handle($cache);
    $gobj->cache_expires($expire_time);
    $gobj->cache_inited(1);

}

sub cache_inited {
    my ($gobj, $p) = @_;

    $$gobj{__CACHE_INITED__} = $p if defined $p;
    return($$gobj{__CACHE_INITED__});

}

sub cache_handle {
    my ($gobj, $p) = @_;

    $$gobj{__CACHE_HANDLE__} = $p if defined $p;
    return($$gobj{__CACHE_HANDLE__});

}

sub cache_namespace {
    my ($gobj, $p) = @_;

    $$gobj{__CACHE_NAMESPACE__} = $p if defined $p;
    return($$gobj{__CACHE_NAMESPACE__});

}

sub cache_expires {
    my ($gobj, $p) = @_;

    $$gobj{__CACHE_EXPIRES__} = $p if defined $p;
    return($$gobj{__CACHE_EXPIRES__});

}

sub cache_get {
    my ($gobj, $key) = @_;

    my $handle = $gobj->cache_handle();
    my $namespace = $gobj->cache_namespace();
    my $skey = $namespace . ':' . $key;

    return $handle->get($skey);

}

sub cache_set {
    my ($gobj, $key, $val) = @_;

    my $handle = $gobj->cache_handle();
    my $namespace = $gobj->cache_namespace();
    my $skey = $namespace . ':' . $key;

    $handle->set($skey, $val);

}

sub cache_del {
    my ($gobj, $key) = @_;

    my $handle = $gobj->cache_handle();
    my $namespace = $gobj->cache_namespace();
    my $skey = $namespace . ':' . $key;

    $handle->remove($skey);
    
}

1;

__END__

=head1 NAME

Gantry::Cache::FastMmap - A Plugin interface to a caching subsystem

=head1 SYNOPSIS

It is sometimes desireable to cache data between page accesess. This 
module gives access to the Cache::FastMmap module to store that data.
  
Inside MyApp.pm
  
    use Gantry::Cache::FastMmap;

=head1 DESCRIPTION

This plugin mixes in methods to store data within a cache. This data
is then available for later retrival. Data is stored within the cache 
by key/value pairs. There are no restrictions on what information can be 
stored. This cache is designed for short term data storage. Cached 
data items will be timed out and purged at regular intervals. The caching 
system also has the concept of namespace. Namespaces are being used to make 
key's unique. So you may store multiple unique data items within
the cache.

=head1 CONFIGURATION

The following items can be set by configuration:

 cache_pages            the number of pages within the cache
 cache_pagesize         the sixe of those pages
 cache_expires          the expiration of items within the cache
 cache_filename         the cache filename

The following reasonable defaults are being used for those items:

 cache_pages            256
 cache_pagesize         256k
 cache_expires          1h
 cache_filename         /tmp/gantry.cache

Since this cache is being managed by Cache::FastMmap, any changes to those
defaults should be consistent with that modules usage. Also note that 
memory consumption may seem excessive. This may cause problems on your
system, so the Cache::FastMmap man pages will explain how to deal with
those issue.

=head1 METHODS

=over 4

=item cache_init

This method will initialize the cache. It should be called only once within 
the application.

 $self->cache_init();

=item cache_namespace

This method will get/set the current namespace for cache operations.

 $self->cache_namespace($namespace);

=item cache_handle

This method returns the handle for the underlining cache. You can use
this handle to manipulate the cache directly. Doing so will be highly
specific to the underling cache handler.

 $handle = $self->cache_handle();

=item cache_get

This method returns the data associated with the current namespace/key 
combination.

 $self->cache_namespace($namespace);
 $data = $self->cache_get($key);

=item cache_set

This method stores the data associated with the current namespace/key
combination.

 $self->cache_namespace($namespace);
 $self->cache_set($key, $data);

=item cache_del

This method removes the data associated with the current namespace/key 
combination.

 $self->cache_namespace($namespace);
 $self->cache_del($key);

=item cache_expires

Retrieves the current expiration time for data items within the cache. The 
expiration time is set when the cache is initially initialize. So setting 
it will not change anything. Expiration time formats are highly specific to 
the underlining cache handler.

 $expiration = $self->cache_expires();

=back

=head1 SEE ALSO

    Gantry

=head1 AUTHOR

Kevin L. Esteb <kesteb@wsipc.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 Kevin L. Esteb

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut

