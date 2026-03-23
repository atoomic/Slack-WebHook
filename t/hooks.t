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
        note "calling HTTP::Tiny post_form mocked method";
        $last_http_post_form = \@args;
        return { success => 1, status => 200, reason => 'OK' };
    }
);

like(
    dies { Slack::WebHook->new()->post("no URL...") },
    qr/\QMissing URL, please set it using Slack::WebHook->new( url => ... )\E/,
    "Dies when missing URL"
);

ok !$last_http_post_form, "post_form was not called";

{
    note "post() with zero args dies";
    my $h = Slack::WebHook->new( url => 'http://127.0.0.1' );
    like(
        dies { $h->post() },
        qr/post method requires one argument/,
        "Dies when calling post() with no arguments"
    );
}

{
    note "odd args error message includes caller";
    my $h = Slack::WebHook->new( url => 'http://127.0.0.1' );
    like(
        dies { $h->post_ok( 'a', 'b', 'c' ) },
        qr/Invalid number of args from/,
        "Dies on odd number of args"
    );
}

{
    note "post_end() without post_start() warns";

    my $h = Slack::WebHook->new( url => 'http://127.0.0.1' );
    my @warnings;
    {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        $h->post_end('finished without starting');
    }
    like(
        \@warnings,
        [ match qr/post_end\(\) called without a prior post_start\(\)/ ],
        "Warns when post_end is called without post_start"
    );
    # elapsed should be 0 (time() - time()), so no run time in output
    undef $last_http_post_form;
}

my $URL  = 'http://127.0.0.1';
my $hook = Slack::WebHook->new( url => $URL );

ok( ref( $hook->json ), "store a JSON object" );

$hook->post('a raw message');
http_post_was_called_with( { text => 'a raw message' }, 'a raw message using post' );

$hook->post( { text => 'my custom message', custom => 'field' } );
http_post_was_called_with(
    {
        'custom' => 'field',
        'text'   => 'my custom message'
    },
    'a custom hash using post'
);

{
    note "post_ok";

    $hook->post_ok('posting a simple "ok" text');
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => 'posting a simple "ok" text'
                }
            ]
        },
        'post_ok( msg )'
    );

    $hook->post_ok(
        title => 'My Title',
        body  => qq[This is a message\nwith another line]
    );
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text'  => "This is a message\nwith another line",
                    'title' => 'My Title'
                }
            ]
        },
        'post_ok( @list )'
    );

}

{
    note "utf8";

    my $msg = q[Starts of "école"];
    $hook->post($msg);
    http_post_was_called_with(
        { 'text' => $msg },
        'post( msg ) with utf8 characters'
    );

}

{
    note "utf8 detection in attachment-based posts (post_ok, etc.)";

    # Build a byte string containing valid UTF-8 bytes for "ecole" with accent
    # \xc3\xa9 = UTF-8 encoding of U+00E9 (e-acute)
    my $utf8_text  = "D\xc3\xa9ploiement de l'\xc3\xa9cole";
    my $utf8_title = "R\xc3\xa9sum\xc3\xa9";

    ok !Encode::is_utf8($utf8_text),  "text starts without utf8 flag";
    ok !Encode::is_utf8($utf8_title), "title starts without utf8 flag";

    $hook->post_ok(
        title => $utf8_title,
        text  => $utf8_text,
    );

    # Verify the raw payload string - check that the JSON does NOT contain
    # double-encoded UTF-8 (Latin-1 interpretation of the bytes).
    # Without the fix, \xc3\xa9 is treated as two Latin-1 chars (U+00C3, U+00A9)
    # which JSON::XS encodes as "\xc3\x83\xc2\xa9" (double-encoded) or as
    # escaped sequences. With the fix, _utf8_on makes JSON see U+00E9 (correct).
    is $last_http_post_form, [
        $URL,
        { payload => D() }
      ],
      "post_form was called for utf8 attachment test"
      or die;

    my $payload = $last_http_post_form->[1]->{payload};

    # The payload should contain the properly encoded e-acute character,
    # not the double-encoded version. Check via JSON decode that the
    # text field roundtrips to the correct Unicode character.
    my $content = JSON::XS->new->utf8(0)->decode($payload);
    my $att = $content->{attachments}[0];

    # If auto_detect_utf8 worked, the text should contain U+00E9 (e-acute)
    # If it didn't work, text contains U+00C3 U+00A9 (double-encoded garbage)
    like $att->{text}, qr/\x{e9}cole/, "attachment text has correct e-acute (U+00E9), not double-encoded";
    like $att->{title}, qr/R\x{e9}sum\x{e9}/, "attachment title has correct e-acute (U+00E9)";

    undef $last_http_post_form;
}

{
    note "utf8 in post_ok (attachment-level auto-detect)";

    my $msg = q[Début de "tâche"];
    $hook->post_ok($msg);
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => $msg
                }
            ]
        },
        'post_ok( msg ) with utf8 characters in attachment'
    );

    $hook->post_warning(
        title => "Alerte éducation",
        text  => "Les élèves sont prêts"
    );
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_WARNING,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text'  => "Les élèves sont prêts",
                    'title' => "Alerte éducation"
                }
            ]
        },
        'post_warning( @list ) with utf8 in title and text'
    );
}

{
    note "post_warning";

    $hook->post_warning('posting a simple "warning" text');
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#f5ca46',
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => 'posting a simple "warning" text'
                }
            ]
        },
        'post_warning( txt )'
    );

    $hook->post_warning(
        title => ':warning: Warning Title',
        text  => 'this is the _warning_ message'
    );

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#f5ca46',
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text'  => 'this is the _warning_ message',
                    'title' => ':warning: Warning Title'
                }
            ]
        },
        'post_warning( @list )'
    );

}

{
    note "post_error";

    $hook->post_error('posting a simple *"error"* message');
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#cc0000',
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => 'posting a simple *"error"* message'
                }
            ]
        },
        'post_error( txt )'
    );

    $hook->post_error(
        title => ':criticalfail: Error Title',
        text  => 'this is the _error_ message'
    );

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#cc0000',
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text'  => 'this is the _error_ message',
                    'title' => ':criticalfail: Error Title'
                }
            ]
        },
        'post_error( @list )'
    );

}

{
    note "start / stop";

    $hook->post_start('starting some task');

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#2b3bd9',
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => 'starting some task'
                }
            ]
        },
        'post_start( txt )'
    );

    $hook->_started_at( time() - ( 1 * 3600 + 12 * 60 + 45 ) );
    $hook->post_end('task is now finished');

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#2eb886',
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => "task is now finished\n" . "_run time: 1 hour 12 minutes 45 seconds_"
                }
            ]
        },
        'post_end( txt ) - 1 hour 12 minutes 45 seconds'
    );

    # ----

    $hook->post_start( title => "Starting Task 42", text => "description..." );

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#2b3bd9',
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text'  => 'description...',
                    'title' => 'Starting Task 42'
                }
            ]
        },
        'post_start( @list )'
    );

    $hook->_started_at( time() - 18 );
    $hook->post_end(
        title => "Task 42 is now finished", color => "#000",
        text  => 'task is now finished'
    );

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => '#000',
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text'  => "task is now finished\n" . '_run time: 18 seconds_',
                    'title' => 'Task 42 is now finished'
                }
            ]
        },
        'post_end( @list ) with custom color'
    );
}

{
    note "post_end with exact minutes (no remaining seconds)";

    $hook->_started_at( time() - 120 );
    $hook->post_end('exactly two minutes');

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => "exactly two minutes\n" . '_run time: 2 minutes_'
                }
            ]
        },
        'post_end with exact minutes still shows run time'
    );
}

{
    note "post_end with exact hours (no remaining seconds or minutes)";

    $hook->_started_at( time() - 3600 );
    $hook->post_end('exactly one hour');

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => "exactly one hour\n" . '_run time: 1 hour_'
                }
            ]
        },
        'post_end with exact hours still shows run time'
    );
}

{
    note "_http_post warns on HTTP failure";

    $mock_http->redefine(
        post_form => sub {
            my ( $self, @args ) = @_;
            $last_http_post_form = \@args;
            return { success => '', status => 404, reason => 'Not Found' };
        }
    );

    my @warnings;
    {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        $hook->post('trigger http failure');
    }
    like(
        \@warnings,
        [ match qr/Slack webhook POST failed: HTTP 404 Not Found/ ],
        "Warns when HTTP response has success=false"
    );
    undef $last_http_post_form;

    # restore success mock for remaining tests
    $mock_http->redefine(
        post_form => sub {
            my ( $self, @args ) = @_;
            $last_http_post_form = \@args;
            return { success => 1, status => 200, reason => 'OK' };
        }
    );
}

{
    note "post_info";

    $hook->post_info('posting a simple "info" text');
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_INFO,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => 'posting a simple "info" text'
                }
            ]
        },
        'post_info( txt )'
    );

    $hook->post_info(
        title => ':info: Info Title',
        text  => 'this is the _info_ message'
    );

    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_INFO,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text'  => 'this is the _info_ message',
                    'title' => ':info: Info Title'
                }
            ]
        },
        'post_info( @list )'
    );
}

{
    note "post() with too many args dies";
    my $h = Slack::WebHook->new( url => 'http://127.0.0.1' );
    like(
        dies { $h->post( 'a', 'b' ) },
        qr/post method only takes one argument/,
        "Dies when calling post() with two arguments"
    );
}

{
    note "notify_slack with single string arg";

    $hook->notify_slack('direct string message');
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => 'direct string message'
                }
            ]
        },
        'notify_slack( single_string )'
    );
}

{
    note "notify_slack with content alias for text";

    $hook->notify_slack( content => 'via content alias' );
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => 'via content alias'
                }
            ]
        },
        'notify_slack( content => ... ) uses content as text alias'
    );
}

{
    note "notify_slack with body alias for text";

    $hook->notify_slack( body => 'via body alias' );
    http_post_was_called_with(
        {
            'attachments' => [
                {
                    'color'     => Slack::WebHook::SLACK_COLOR_OK,
                    'mrkdwn_in' => [
                        'text',
                        'title'
                    ],
                    'text' => 'via body alias'
                }
            ]
        },
        'notify_slack( body => ... ) uses body as text alias'
    );
}

{
    note "notify_slack with zero args dies";

    like(
        dies { $hook->notify_slack() },
        qr/No arguments to notify_slack/,
        "Dies on zero args to notify_slack"
    );
}

{
    note "notify_slack with odd number of args dies";

    like(
        dies { $hook->notify_slack( 'a', 'b', 'c' ) },
        qr/Invalid number of arguments/,
        "Dies on odd number of args to notify_slack"
    );
}

{
    note "auto_detect_utf8 disabled";

    my $h = Slack::WebHook->new( url => 'http://127.0.0.1', auto_detect_utf8 => 0 );
    ok !$h->auto_detect_utf8, "auto_detect_utf8 is off";

    # Post a byte string with valid UTF-8 bytes
    my $byte_text = "D\xc3\xa9j\xc3\xa0 vu";
    ok !Encode::is_utf8($byte_text), "text starts without utf8 flag";

    $h->post_ok( text => $byte_text );

    # With auto_detect_utf8 off, the JSON encoder gets the raw bytes,
    # which JSON::XS with utf8(0) will encode as Latin-1 codepoints
    ok defined $last_http_post_form, "post_form was called with auto_detect_utf8 off";

    my $payload = $last_http_post_form->[1]->{payload};
    my $content = JSON::XS->new->utf8(0)->decode($payload);
    my $att     = $content->{attachments}[0];

    # Without utf8 detection, the bytes are treated as Latin-1,
    # so \xc3 becomes U+00C3 and \xa9 becomes U+00A9 (double-encoded)
    like $att->{text}, qr/\x{c3}\x{a9}/, "text has raw bytes (not decoded) when auto_detect_utf8 is off";

    undef $last_http_post_form;
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

    undef $last_http_post_form;    # reset;

    return;
}
