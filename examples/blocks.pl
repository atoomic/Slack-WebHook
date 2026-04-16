use Slack::WebHook ();

my $hook = Slack::WebHook->new( url => 'https://hooks.slack.com/services/xxxx/xxxx...' );

# Block Kit is Slack's modern message format (https://api.slack.com/block-kit).
# The colored post_* methods use the legacy "attachments" format. For richer
# layouts (sections, dividers, buttons, fields, ...) pass a Block Kit payload
# directly through post():

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
