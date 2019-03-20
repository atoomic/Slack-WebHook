# NAME

Slack::WebHook - Slack WebHook with preset layout & colors for sending slack notifications

# VERSION

version 0.001

# SYNOPSIS

Sample usage to post slack notifications using Slack::WebHook

```perl
#!perl

use Slack::WebHook ();

my $hook = Slack::WebHook->new( 
               url => 'https://hooks.slack.com/services/xxxx/xxxx...' 
);

# using some preset decorations with markdown syntax enabled
$hook->post_ok( 'a pretty _green_ message' );
$hook->post_warning( 'a pretty _orange_ message' );
$hook->post_error( 'a pretty _red_ message' );
$hook->post_info( 'a pretty _blue_ message' );

# this is similar to the previous syntax
$hook->post_ok( text => 'a pretty _green_ message' );

# you can also set a title and a body to your message
# with any of the post_* methods
$hook->post_ok( # or any other post_* method
       title   => ':camel: My Title',
       text    => qq[A multiline\ncontent as an example],
);

# you can also set your own color if you want
$hook->post_info( # or any other post_* method
       color   => '#00cc00',
       text    => q[Hello, World! in green],
);

{
       # using timers for your tasks
       $hook->post_start( 'starting some task' );
       sleep( 1 * 3600 + 12 * 60 + 45 ) if 0; # 1 hour 12 minutes 45 seconds
       $hook->post_end( 'task is now finished' );
       # automatically adds the run time at the end of your message:
       #       "\nrun time: 1 hour 12 minutes 45 seconds" 
}

# using a custom color to a notification
$hook->post_end( text => 'task is now finished in black', color => '#000' );

# you can also post your own custom message without any preset styles
#      this allow you to bypass the custom layout and provide your own hash struct
#      which will be converted to JSON before posting the message
$hook->post( 'posting a raw message' );
$hook->post( { text => 'Hello, World!'} );
```

# DESCRIPTION

Slack::WebHook

Set of helpers to send slack notification with preset decorations.

# Available functions / methods

## new( \[ url => "https://..." \] )

This is the constructor for [Slack::WebHook](https://metacpan.org/pod/Slack::WebHook). You should provide the `url` for your webhook.
You should visit the [official Slack documentation page](https://api.slack.com/slack-apps) to create your webhook
and get your personal URL.

## post( $message )

The [post](https://metacpan.org/pod/post) method allow you to post a single message without any preset decorations.
The return value is the return of [HTTP::Tiny::post\_form](https://metacpan.org/pod/HTTP::Tiny::post_form) which is one `Hash Ref`.
The `success` field will be true if the status code is 2xx.

You should prefer using any of the other methods `post_*` which will use colors
and a preset style to display your notification.
The `post` method allow you to post custom messages by bypassing any preset layour.

## post\_ok( $message, \[ @list \] )

[post\_ok](https://metacpan.org/pod/post_ok) submit a POST request to the Http URL set when constructing a [Slack::WebHook](https://metacpan.org/pod/Slack::WebHook) object.
You have two ways of calling a `post_*` method.

Either you can simply pass a single string argument to the function

```perl
    Slack::WebHook->new( URL => ... )->post_ok( q[posting a simple "ok" text] );
```

or you can also set an optional title or change the default color used for the notification

```perl
    Slack::WebHook->new( URL => ... )
        ->post_ok( 
            title  => ":camel: Notification Title",
            text   => "your notification message using _markdown_",
            #color => '#aabbcc',
        );
```

The return value of the method `post_*` is one [HTTP::Tiny](https://metacpan.org/pod/HTTP::Tiny) reply. One `Hash Ref` containing
the `success` field which is true on success.

## post\_warning( $message, \[ @list \] )

Similar to [post\_ok](https://metacpan.org/pod/post_ok) but the color used to display the message is `yellow`.

## post\_info( $message, \[ @list \] )

Similar to [post\_ok](https://metacpan.org/pod/post_ok) but the color used to display the message is `blue`.

## post\_error( $message, \[ @list \] )

Similar to [post\_ok](https://metacpan.org/pod/post_ok) but the color used to display the message is `red`.

## post\_start( $message, \[ @list \] )

Similar to [post\_ok](https://metacpan.org/pod/post_ok) but in addition initialize a timer which is used by [post\_stop](https://metacpan.org/pod/post_stop).
The default color used to display the message is `blue`.

## post\_end( $message, \[ @list \] )

The [post\_end](https://metacpan.org/pod/post_end) method should be used after calling [post\_start](https://metacpan.org/pod/post_start). 
This would convert the time elapsed between the two calls to a string appended at the end
of your message.

The default notification color is `green`.

```perl
my $hook = Slack::WebHook->new( url => 'https://...' );

# simple start / end
$hook->post_start( 'starting some task' );
sleep( 1 * 3600 + 12 * 60 + 45 ); # 1 hour 12 minutes and 45 seconds
$hook->post_end( 'task is now finished' );

# using start / end with title and custom color
$hook->post_start( title => "Starting Task 42", text => "description..." );
sleep( 18 );
$hook->post_end( title => "Task 42 is now finished", color => "#000", text => 'task is now finished' );
```

# Customize notifications colors

Using any of the `post_*` methods: [post\_ok](https://metacpan.org/pod/post_ok), [post\_warning](https://metacpan.org/pod/post_warning), [post\_error](https://metacpan.org/pod/post_error), [post\_info](https://metacpan.org/pod/post_info), [post\_start](https://metacpan.org/pod/post_start) 
or [post\_end](https://metacpan.org/pod/post_end) you can set an alternate color to use for your Slack notification.

```perl
my $webhook = Slack::WebHook->new( url => '...' );

# message without a title using a custom color
$webhook->post_ok( { text => 'Hello World! in black', color => '#000' );

# message with a title using a custom color
$webhook->post_warning( { title => 'My Title', text => 'Hello World! in red', color => '#cc0000' );
```

# SEE ALSO

Please also consider the following modules:

- [Slack::Notify](https://metacpan.org/pod/Slack::Notify) - powerful client for Slack webhooks which gives you a full control on the message layout

# TODO

- improve doc & add some extra examples
- markdown on demand?
- simplify return value from post\_\* methods?

# LICENSE

This software is copyright (c) 2019 by cPanel, L.L.C.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming
language system itself.

# DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY
APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE
SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE
OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY
WHO MAY MODIFY AND/OR REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR
THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS
BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

# AUTHOR

Nicolas R <atoomic@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by cPanel, Inc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
