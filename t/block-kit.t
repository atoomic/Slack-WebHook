#!/usr/bin/env perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockModule ();

use Slack::WebHook ();
use JSON::XS       ();

my $last_http_post;

my $mock_http = Test::MockModule->new('HTTP::Tiny');
$mock_http->redefine(
    post_form => sub {
        my ( $self, @args ) = @_;
        $last_http_post = \@args;
        return { success => 1, status => 200, reason => 'OK' };
    }
);

my $URL  = 'http://127.0.0.1';
my $json = JSON::XS->new->utf8(0);

sub decode_payload {
    my $payload = $last_http_post->[1]->{payload};
    return $json->decode($payload);
}

# --- Default format is 'attachment' ---

{
    note "default format is 'attachment'";
    my $hook = Slack::WebHook->new( url => $URL );
    is $hook->format, 'attachment', "default format is attachment";
}

# --- Block Kit mode ---

{
    note "format => 'blocks' produces Block Kit structure";
    my $hook = Slack::WebHook->new( url => $URL, format => 'blocks' );
    is $hook->format, 'blocks', "format is blocks";

    $hook->post_ok('deploy successful');
    my $data = decode_payload();

    ok exists $data->{blocks}, "blocks key present";
    ok !exists $data->{attachments}, "no attachments key";

    is scalar @{ $data->{blocks} }, 1, "one block";
    is $data->{blocks}[0]{type}, 'section', "block type is section";
    is $data->{blocks}[0]{text}{type}, 'mrkdwn', "text type is mrkdwn";
    like $data->{blocks}[0]{text}{text}, qr/deploy successful/, "message text present";
    like $data->{blocks}[0]{text}{text}, qr/\x{2705}/, "contains check mark emoji for OK";

    undef $last_http_post;
}

{
    note "block kit post_warning uses warning emoji";
    my $hook = Slack::WebHook->new( url => $URL, format => 'blocks' );

    $hook->post_warning('disk space low');
    my $data = decode_payload();

    like $data->{blocks}[0]{text}{text}, qr/disk space low/, "warning text present";
    like $data->{blocks}[0]{text}{text}, qr/\x{26A0}/, "contains warning emoji";

    undef $last_http_post;
}

{
    note "block kit post_error uses error emoji";
    my $hook = Slack::WebHook->new( url => $URL, format => 'blocks' );

    $hook->post_error('connection failed');
    my $data = decode_payload();

    like $data->{blocks}[0]{text}{text}, qr/connection failed/, "error text present";
    like $data->{blocks}[0]{text}{text}, qr/\x{274C}/, "contains cross mark emoji";

    undef $last_http_post;
}

{
    note "block kit post_info uses info emoji";
    my $hook = Slack::WebHook->new( url => $URL, format => 'blocks' );

    $hook->post_info('version 3.2 available');
    my $data = decode_payload();

    like $data->{blocks}[0]{text}{text}, qr/version 3.2 available/, "info text present";
    like $data->{blocks}[0]{text}{text}, qr/\x{2139}/, "contains info emoji";

    undef $last_http_post;
}

{
    note "block kit with title renders bold title";
    my $hook = Slack::WebHook->new( url => $URL, format => 'blocks' );

    $hook->post_ok( title => 'Deploy v2.1', text => 'all green' );
    my $data = decode_payload();

    like $data->{blocks}[0]{text}{text}, qr/\*Deploy v2\.1\*/, "title rendered bold";
    like $data->{blocks}[0]{text}{text}, qr/all green/, "body text present";

    undef $last_http_post;
}

{
    note "block kit post_start uses rocket emoji";
    my $hook = Slack::WebHook->new( url => $URL, format => 'blocks' );

    $hook->post_start('building artifact');
    my $data = decode_payload();

    like $data->{blocks}[0]{text}{text}, qr/building artifact/, "start text present";
    like $data->{blocks}[0]{text}{text}, qr/\x{1F680}/, "contains rocket emoji";

    undef $last_http_post;
}

{
    note "block kit post_end includes run time";
    my $hook = Slack::WebHook->new( url => $URL, format => 'blocks' );

    $hook->_started_at( time() - 65 );
    $hook->post_end('build complete');
    my $data = decode_payload();

    like $data->{blocks}[0]{text}{text}, qr/build complete/, "end text present";
    like $data->{blocks}[0]{text}{text}, qr/1 minute 5 seconds/, "includes elapsed time";

    undef $last_http_post;
}

{
    note "post() bypasses format setting (always raw)";
    my $hook = Slack::WebHook->new( url => $URL, format => 'blocks' );

    $hook->post('raw message');
    my $data = decode_payload();

    is $data, { text => 'raw message' }, "post() sends raw payload regardless of format";

    undef $last_http_post;
}

{
    note "post() with hashref bypasses format setting";
    my $hook = Slack::WebHook->new( url => $URL, format => 'blocks' );

    $hook->post({ blocks => [{ type => 'section', text => { type => 'mrkdwn', text => 'custom' } }] });
    my $data = decode_payload();

    ok exists $data->{blocks}, "custom blocks passed through";
    is $data->{blocks}[0]{text}{text}, 'custom', "custom block content preserved";

    undef $last_http_post;
}

## final sanity check
is $last_http_post, undef, "all calls were checked";

done_testing;
