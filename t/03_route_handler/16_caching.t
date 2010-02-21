#!perl

# testing caching mechanism

use strict;
use warnings;

use Test::More tests => 28, import => ['!pass'];
use lib 't';
use TestUtils;

use Dancer;
use Dancer::Config 'setting';

setting cache => 1;

{
    use Dancer::Route::Cache;
    # checking the size parsing
    my %sizes = (
        '1G'  => 1073741824,
        '10M' => 10485760,
        '10K' => 10240,
        '300' => 300,
    );

    while ( my ( $size, $expected ) = each %sizes ) {
        my $got = Dancer::Route::Cache->parse_size($size);
        cmp_ok( $got, '==', $expected, "Parsing $size correctly ($got)" );
    }

    # checking we can start cache correctly
    my $cache = Dancer::Route::Cache->new(
        size_limit => '10M',
        path_limit => 10

    );

    cmp_ok( $cache->size_limit, '==', $sizes{'10M'}, 'setting size_limit' );
    cmp_ok( $cache->path_limit, '==', 10,            'setting path_limit' );
}

# running three routes
# GET and POST with in pass to 'any'
ok( get(  '/:p', sub { params->{'p'} eq 'in' or pass } ), 'adding POST /:p' );
ok( post( '/:p', sub { params->{'p'} eq 'in' or pass } ), 'adding GET  /:p' );
ok( any(  '/:p', sub { 'any' } ),                         'adding any  /:p' );

my %reqs = (
    '/'    => 'GET / request',
    '/var' => 'GET /var request',
);

foreach my $method ( qw/get post/ ) {
    foreach my $path ( '/in', '/out', '/err' ) {
        my $req = TestUtils::fake_request( $method => $path );
        Dancer::SharedData->request($req);
        my $res = Dancer::Renderer::get_action_response();

        ok( defined $res, "$method $path request" );
    }
}

my $cache = Dancer::Route->cache;
isa_ok( $cache, 'Dancer::Route::Cache' );

# checking when path doesn't exist
is(
    $cache->route_from_path( get => '/wont/work'),
    undef,
    'non-existing path',
);

is(
    $cache->route_from_path( post => '/wont/work'),
    undef,
    'non-existing path',
);

foreach my $method ( qw/get post/ ) {
    foreach my $path ( '/in', '/out', '/err' ) {
        my $route = $cache->route_from_path( $method, $path );
        is( ref $route, 'HASH', "Got route for $path ($method)" );
    }
}

# since "/out" and "/err" aren't "/in", both GET and POST delegate to "any()"
# that means that "/out" and "/err" on GET should be the same as on POST

foreach my $path ( '/out', '/err' ) {
    my %content; # by method
    foreach my $method ( qw/get post/ ) {
        my $handler = $cache->route_from_path( $method => $path );
        ok( $handler, "Got handler for $method $path" );
        if ($handler) {
            $content{$method} = $handler->{'content'};
        }
    }

    if ( defined $content{'get'} and defined $content{'post'} ) {
        is( $content{'get'}, $content{'post'}, "get/post $path is the same" );
    }
}

# testing path_limit

# running two more routes

# checking to see only one was added to the cache

# testing size_limit

