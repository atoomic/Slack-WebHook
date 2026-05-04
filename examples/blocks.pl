use Slack::WebHook ();

my $hook = Slack::WebHook->new( url => 'https://hooks.slack.com/services/xxxx/xxxx...' );

# --- Using format => 'blocks' for convenience methods ---
# Block Kit mode adds emoji prefixes to indicate severity instead of
# the colored sidebars used by the legacy attachment format.

my $bk = Slack::WebHook->new( url => 'https://...', format => 'blocks' );

$bk->post_ok('deploy successful');       # check-mark deploy successful
$bk->post_warning('disk space low');     # warning-sign disk space low
$bk->post_error('connection failed');    # cross-mark connection failed

# --- Manual Block Kit via post() ---
# For full control over the layout (sections, dividers, buttons, fields, ...)
# pass a Block Kit payload directly through post():

$hook->post(
    {
        blocks => [
            {
                type => 'section',
                text => {
                    type => 'mrkdwn',
                    text => '*Build finished* :white_check_mark:',
                },
            },
            { type => 'divider' },
            {
                type   => 'section',
                fields => [
                    { type => 'mrkdwn', text => "*Branch:*\nmain" },
                    { type => 'mrkdwn', text => "*Duration:*\n3m 41s" },
                ],
            },
        ],
    }
);
