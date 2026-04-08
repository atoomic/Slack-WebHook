#!/usr/bin/env perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockModule ();

use Slack::WebHook ();
use JSON::XS       ();

our $last_http_post_form;

my $mock_http = Test::MockModule->new('HTTP::Tiny');
$mock_http->redefine(
    post_form => sub {
        my ( $self, @args ) = @_;
        $last_http_post_form = \@args;
        return { success => 1, status => 200, reason => 'OK' };
    }
);

my $URL  = 'http://127.0.0.1';
my $hook = Slack::WebHook->new( url => $URL );

# --- post_info: the only post_* method without test coverage ---

{
    note "post_info with simple message";

    $hook->post_info('an info message');
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_INFO,
                    'mrkdwn_in' => [ 'text', 'title' ],
                    'text'      => 'an info message'
                }
            ]
        },
        'post_info( txt )'
    );
}

{
    note "post_info with title and text";

    $hook->post_info(
        title => ':information_source: Info Title',
        text  => 'this is the _info_ message'
    );
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_INFO,
                    'mrkdwn_in' => [ 'text', 'title' ],
                    'text'      => 'this is the _info_ message',
                    'title'     => ':information_source: Info Title'
                }
            ]
        },
        'post_info( @list )'
    );
}

{
    note "post_info with custom color override";

    $hook->post_info(
        color => '#abcdef',
        text  => 'custom colored info'
    );
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#abcdef',
                    'mrkdwn_in' => [ 'text', 'title' ],
                    'text'      => 'custom colored info'
                }
            ]
        },
        'post_info with custom color'
    );
}

# --- post() with too many args ---

{
    note "post() with too many args dies";

    like(
        dies { $hook->post( 'a', 'b' ) },
        qr/post method only takes one argument/,
        "Dies when calling post() with two arguments"
    );
}

# --- notify_slack single-arg path (public API) ---

{
    note "notify_slack with single string argument";

    $hook->notify_slack('direct notify call');
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [ 'text', 'title' ],
                    'text'      => 'direct notify call'
                }
            ]
        },
        'notify_slack( single_string )'
    );
}

# --- content alias in notify_slack ---

{
    note "notify_slack 'content' alias for text";

    $hook->notify_slack(
        color   => '#112233',
        content => 'message via content alias'
    );
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#112233',
                    'mrkdwn_in' => [ 'text', 'title' ],
                    'text'      => 'message via content alias'
                }
            ]
        },
        'notify_slack content alias'
    );
}

# --- post_end with 0 elapsed (same-second start/end) ---

{
    note "post_end with 0 elapsed omits run time";

    $hook->_started_at( time() );
    $hook->post_end('instant task');

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [ 'text', 'title' ],
                    'text'      => 'instant task'
                }
            ]
        },
        'post_end with 0 elapsed has no run time suffix'
    );
}

# --- notify_slack with zero args dies ---

{
    note "notify_slack with zero args dies";

    like(
        dies { $hook->notify_slack() },
        qr/No arguments to notify_slack/,
        "Dies when calling notify_slack() with no arguments"
    );
}

# --- notify_slack with odd number of args dies ---

{
    note "notify_slack with odd args (3) dies";

    like(
        dies { $hook->notify_slack( 'a', 'b', 'c' ) },
        qr/Invalid number of arguments/,
        "Dies when calling notify_slack() with odd number of args > 1"
    );
}

## final sanity check
note "final sanity check";
is $last_http_post_form, undef, "all calls were checked"
  or diag explain $last_http_post_form;

done_testing;

sub http_post_was_called_with {
    my ( $expect, $msg ) = @_;

    $msg //= 'http_post_was_called_with';

    is $last_http_post_form, [
        $URL,
        { payload => D() }
      ],
      "last_http_post_form called"
      or die;

    my $content = eval { JSON::XS->new->utf8(0)->decode( $last_http_post_form->[1]->{payload} ) };
    diag "Error: ", $@ if $@;
    is( $content, $expect, $msg ) or diag explain $content, explain $last_http_post_form->[1]->{payload};

    undef $last_http_post_form;

    return;
}
