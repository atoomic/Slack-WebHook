#!/usr/bin/env perl

# Integration test: validates that HTTP requests sent by Slack::WebHook
# use proper JSON format (Content-Type: application/json, JSON body).
#
# Spins up a local HTTP server to capture the raw request.

use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Warnings qw/no_warnings/;
use IO::Socket::INET ();
use JSON::XS         ();

use Slack::WebHook ();

# --- helpers ---

# Start a one-shot HTTP listener, return ($port, $socket)
sub start_listener {
    my $server = IO::Socket::INET->new(
        LocalAddr => '127.0.0.1',
        LocalPort => 0,          # OS picks a free port
        Listen    => 1,
        ReuseAddr => 1,
    ) or die "Cannot create listener: $!";

    return ( $server->sockport, $server );
}

# Accept one request, return { method, path, headers => {lc_name => value}, body }
sub accept_one_request {
    my ($server) = @_;

    my $client = $server->accept or die "accept: $!";
    $client->autoflush(1);

    # Read request line
    my $request_line = <$client>;
    chomp $request_line;
    my ( $method, $path ) = split /\s+/, $request_line;

    # Read headers
    my %headers;
    while ( my $line = <$client> ) {
        $line =~ s/\r?\n$//;
        last if $line eq '';
        if ( $line =~ /^([^:]+):\s*(.*)$/ ) {
            $headers{ lc($1) } = $2;
        }
    }

    # Read body
    my $body = '';
    if ( my $len = $headers{'content-length'} ) {
        read( $client, $body, $len );
    }

    # Send minimal 200 response
    print $client "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok";
    close $client;

    return {
        method  => $method,
        path    => $path,
        headers => \%headers,
        body    => $body,
    };
}

# --- tests ---

subtest 'post() sends JSON with correct Content-Type' => sub {
    my ( $port, $server ) = start_listener();
    my $hook = Slack::WebHook->new( url => "http://127.0.0.1:$port/webhook" );

    # Fire the request in background (it will block until server accepts)
    my $pid = fork();
    die "fork: $!" unless defined $pid;

    if ( $pid == 0 ) {
        # child: make the request
        $hook->post("hello from integration test");
        exit 0;
    }

    # parent: capture the request
    my $req = accept_one_request($server);
    close $server;
    waitpid( $pid, 0 );

    is $req->{method}, 'POST', 'HTTP method is POST';
    is $req->{path}, '/webhook', 'request path is /webhook';

    like $req->{headers}{'content-type'}, qr{application/json}i,
        'Content-Type is application/json';

    # Body should be valid JSON
    my $decoded = eval { JSON::XS->new->decode( $req->{body} ) };
    ok $decoded, 'body is valid JSON'
        or diag "body was: $req->{body}";

    is $decoded->{text}, 'hello from integration test',
        'JSON body contains the message text';
};

subtest 'post_ok() sends JSON attachment with correct Content-Type' => sub {
    my ( $port, $server ) = start_listener();
    my $hook = Slack::WebHook->new( url => "http://127.0.0.1:$port/webhook" );

    my $pid = fork();
    die "fork: $!" unless defined $pid;

    if ( $pid == 0 ) {
        $hook->post_ok(
            title => "Test Title",
            text  => "Test body",
        );
        exit 0;
    }

    my $req = accept_one_request($server);
    close $server;
    waitpid( $pid, 0 );

    like $req->{headers}{'content-type'}, qr{application/json}i,
        'Content-Type is application/json for attachment post';

    my $decoded = eval { JSON::XS->new->decode( $req->{body} ) };
    ok $decoded, 'body is valid JSON';

    # Should have attachments array
    ok ref $decoded->{attachments} eq 'ARRAY', 'has attachments array';

    my $att = $decoded->{attachments}[0];
    is $att->{title}, 'Test Title', 'attachment title is correct';
    is $att->{text},  'Test body',  'attachment text is correct';
    is $att->{color}, '#2eb886',    'attachment color is green (SLACK_COLOR_OK)';
};

subtest 'post_error() sends JSON with red color' => sub {
    my ( $port, $server ) = start_listener();
    my $hook = Slack::WebHook->new( url => "http://127.0.0.1:$port/webhook" );

    my $pid = fork();
    die "fork: $!" unless defined $pid;

    if ( $pid == 0 ) {
        $hook->post_error("something broke");
        exit 0;
    }

    my $req = accept_one_request($server);
    close $server;
    waitpid( $pid, 0 );

    like $req->{headers}{'content-type'}, qr{application/json}i,
        'Content-Type is application/json for error post';

    my $decoded = eval { JSON::XS->new->decode( $req->{body} ) };
    ok $decoded, 'body is valid JSON';

    my $att = $decoded->{attachments}[0];
    is $att->{text},  'something broke', 'error text is correct';
    is $att->{color}, '#cc0000',         'error color is red';
};

subtest 'UTF-8 content survives JSON encoding' => sub {
    my ( $port, $server ) = start_listener();
    my $hook = Slack::WebHook->new( url => "http://127.0.0.1:$port/webhook" );

    my $pid = fork();
    die "fork: $!" unless defined $pid;

    if ( $pid == 0 ) {
        $hook->post_ok("caf\x{e9} \x{2603}");    # cafe + snowman
        exit 0;
    }

    my $req = accept_one_request($server);
    close $server;
    waitpid( $pid, 0 );

    # Body should be valid UTF-8 JSON
    my $decoded = eval { JSON::XS->new->utf8(1)->decode( $req->{body} ) };
    ok $decoded, 'UTF-8 body is valid JSON'
        or diag "body was: $req->{body}";

    like $decoded->{attachments}[0]{text}, qr/caf/,
        'UTF-8 text survived round-trip';
};

done_testing;
