#!/usr/bin/perl

package LJ::Feed;
use strict;
no warnings 'uninitialized';

use LJ::Entry;
use LJ::Entry::Repost;
use LJ::Request;
use LJ::TimeUtil;
use XML::Atom::Person;
use XML::Atom::Feed;

my %feedtypes = (
    'rss'          => { handler => \&create_view_rss,  need_items => 1 },
    'atom'         => { handler => \&create_view_atom, need_items => 1 },
    'foaf'         => { handler => \&create_view_foaf,                 },
    'yadis'        => { handler => \&create_view_yadis,                },
    'userpics'     => { handler => \&create_view_userpics,             },
    'comments'     => { handler => \&create_view_comments,             },
    'rss_friends'  => { handler => \&create_view_rss,  need_items => 1, paid_only => 1 },
    'atom_friends' => { handler => \&create_view_atom, need_items => 1, paid_only => 1 },
);

sub make_feed {
    my ($u, $remote, $opts) = @_;

    $opts->{pathextra} =~ s!^/(\w+)!!;
    my $feedtype = $1;
    my $viewfunc = $feedtypes{$feedtype};

    # /ya/rss -> special rss for yandex
    if ($feedtype eq 'ya') {
        $opts->{pathextra} =~ s!^/(\w+)!!; # cut off '/rss' part
        $feedtype = $1;
        $viewfunc = $feedtypes{$feedtype} if $feedtype eq 'rss';
        $opts->{include_statistics} = 1;

        my $allowed = 0;
        my $remote_ip = LJ::get_remote_ip();

        foreach my $block ( @LJ::YANDEX_RSS_IP_BLOCKS ) {
            my $net = Net::Netmask->new($block);

            next unless $net->match($remote_ip);
            $allowed = 1;
            last;
        }

        unless ( $allowed ) {
            $opts->{'handler_return'} = 403;
            return undef;
        }
    }

    unless ( $viewfunc ) {
        $opts->{'handler_return'} = 404;
        return undef;
    }

    LJ::Request->notes('codepath' => "feed.$feedtype") if LJ::Request->is_inited;

    my $dbr = LJ::get_db_reader();

    my $user = $u->{'user'};

    LJ::load_user_props($u, qw/journaltitle journalsubtitle opt_synlevel/);

    LJ::text_out(\$u->{$_})
        foreach qw/name url urlname/;

    # opt_synlevel will default to 'full'
    $u->{'opt_synlevel'} = 'full'
        unless $u->{'opt_synlevel'} =~ /^(?:full|summary|title)$/;

    # some data used throughout the channel
    my $journalinfo = {
        u         => $u,
        link      => LJ::journal_base($u) . "/",
        title     => $u->{journaltitle} || $u->{name} || $u->{user},
        subtitle  => $u->{journalsubtitle} || $u->{name},
        builddate => LJ::TimeUtil->time_to_http(time()),
    };

    # if we do not want items for this view, just call out
    $opts->{'contenttype'} = 'text/xml; charset='.$opts->{'saycharset'};

    LJ::run_hooks('make_feed', $feedtype, $u, { remote => $remote });

    return $viewfunc->{handler}->($journalinfo, $u, $opts)
        unless $viewfunc->{need_items};

    # for syndicated accounts, redirect to the syndication URL
    # However, we only want to do this if the data we're returning
    # is similar. (Not FOAF, for example)
    if ( $u->{'journaltype'} eq 'Y' ) {
        my $synurl = $dbr->selectrow_array("SELECT synurl FROM syndicated WHERE userid=$u->{'userid'}");
        return 'No syndication URL available.' unless $synurl;

        $opts->{'redir'} = $synurl;
        return undef;
    }

    my %FORM = LJ::Request->args;

    ## load the itemids
    my (@itemids, @objs);

    # for consistency, we call ditemids "itemid" in user-facing settings
    my $ditemid = $FORM{itemid} + 0;

    if ($ditemid) {
        my $entry = LJ::Entry->new($u, ditemid => $ditemid);

        if ( ! $entry || ! $entry->valid || ! $entry->visible_to($remote) ) {
            $opts->{'handler_return'} = 404;
            return undef;
        }

        if (LJ::Entry::Repost->substitute_content($entry,
                                                 { 'original_post_obj' => \$entry,} )) {

            if ( ! $entry || ! $entry->valid || ! $entry->visible_to($remote) ) {
                $opts->{'handler_return'} = 404;
                return undef;
            }
        }

        push @objs, $entry;
    }
    elsif ($viewfunc->{'paid_only'} && $u->get_cap('paid')) {
        @objs = map { $_->{'entry'} } @{ LJ::Journal::FriendsFeed->get_items(
            'remoteid'      => $remote ? $remote->userid : 0,
            'userid'        => $u->{'userid'},
            'itemshow'      => 25,
        ) };

        # Warning: array @itemids is not filling here, so entries will be outputted without tags.

        $journalinfo->{title} .= ' ' . LJ::Lang::ml('feeds.title.friends');
        $journalinfo->{link}  .= 'friends/';
    }
    else {
        LJ::get_recent_items({
            'remote'        => $remote,
            'userid'        => $u->{'userid'},
            'itemshow'      => 25,
            'order'         => 'logtime',
            'tagids'        => $opts->{tagids},
            'tagmode'       => $opts->{tagmode},
            'itemids'       => \@itemids,
            'friendsview'   => 1,           # this returns rlogtimes
            'dateformat'    => 'S2',        # S2 format time format is easier
            'entry_objects' => \@objs,
            'load_props'    => 1,
            'load_text'     => 1,
        });
    }

    $opts->{'contenttype'} = 'text/xml; charset=' . $opts->{'saycharset'};

    # set last-modified header, then let apache figure out
    # whether we actually need to send the feed.
    my $lastmod = 0;

    for my $obj (@objs) {
        # revtime of the item.
        my $revtime = $obj->prop('revtime');
        $lastmod = $revtime if $revtime > $lastmod;

        unless ($revtime) {
            # use the logtime of the item.
            my $itime = $LJ::EndOfTime - $obj->{rlogtime};
            $lastmod = $itime if $itime > $lastmod;
        }
    }

    LJ::Request->set_last_modified($lastmod) if $lastmod;

    # use this $lastmod as the feed's last-modified time
    # we would've liked to use something like
    # LJ::get_timeupdate_multi instead, but that only changes
    # with new updates and doesn't change on edits.
    $journalinfo->{'modtime'} = $lastmod;

    # regarding $r->set_etag:
    # http://perl.apache.org/docs/general/correct_headers/correct_headers.html#Entity_Tags
    # It is strongly recommended that you do not use this method unless you
    # know what you are doing. set_etag() is expecting to be used in
    # conjunction with a static request for a file on disk that has been
    # stat()ed in the course of the current request. It is inappropriate and
    # "dangerous" to use it for dynamic content.
    if ((my $status = LJ::Request->meets_conditions) != LJ::Request::OK()) {
        $opts->{handler_return} = $status;
        return undef;
    }

    $journalinfo->{email} = $u->email_for_feeds if $u && $u->email_for_feeds;

    # load tags now that we have no chance of jumping out early
    my $logtags = LJ::Tags::get_logtags($u, \@itemids);

    my @cleanitems;

  ENTRY:
    foreach my $entry_obj (@objs) {
        next ENTRY if $entry_obj->poster->{'statusvis'} eq 'S';
        next ENTRY if $entry_obj && $entry_obj->is_suspended_for($remote);

        next ENTRY if $entry_obj->original_post;

        my $ditemid = $entry_obj->{ditemid};
        if ( $LJ::UNICODE && $entry_obj->prop('unknown8bit') ) {
            LJ::item_toutf8(
                $u,
                \$entry_obj->{'subject'},
                \$entry_obj->{'event'},
                $entry_obj->prop,
            );
        }

        # see if we have a subject and clean it
        my $subject = $entry_obj->{'subject'};

        if ($subject) {
            $subject =~ s/[\r\n]/ /g;
            LJ::CleanHTML::clean_subject_all(\$subject);
        }

        # an HTML link to the entry. used if we truncate or summarize
        my $readmore = "<b>(<a href=\"$journalinfo->{link}$ditemid.html\">Read more ...</a>)</b>";

        # empty string so we don't waste time cleaning an entry that won't be used
        my $event = $u->{'opt_synlevel'} eq 'title' ? '' : $entry_obj->event_raw;

        # clean the event, if non-empty
        my $ppid = 0;

        if ( $event ) {
            # users without 'full_rss' get their logtext bodies truncated
            # do this now so that the html cleaner will hopefully fix html we break
            unless (LJ::get_cap($u, 'full_rss')) {
                my $trunc = LJ::text_trim($event, 0, 80);
                $event = "$trunc $readmore" if $trunc ne $event;
            }

            LJ::CleanHTML::clean_event(\$event,
                {
                    'wordlength'   => 0,
                    'preformatted' => $entry_obj->prop('opt_preformatted'),
                    'journalid'    => $u->userid,
                    'posterid'     => $entry_obj->{'posterid'},
                    'entry_url'    => $entry_obj->url,
                    'textonly'     => 1,
                }
            );

            # do this after clean so we don't have to about know whether or not
            # the event is preformatted
            if ( $u->{'opt_synlevel'} eq 'summary' ) {
                # assume the first paragraph is terminated by two <br> or a </p>
                # valid XML tags should be handled, even though it makes an uglier regex
                if ( $event =~ m!
                    (.*?)   ## any text
                    (?=<)   ## followed by "<" (zero-width positive look-ahead assertion)
                            ## and then either </p> or 2 BRs,
                            ## where BR is one of: <br></br>, <br> or <br/>
                    ( (?:<br\s*/?\>(?:</br\s*>)?\s*){2} | (?:</p\s*>) ) !six )
                {
                    # everything before the matched tag + the tag itself
                    # + a link to read more
                    $event = $1 . $2 . $readmore;
                }
            }

            while ( $event =~ /<lj-poll-(\d+)>/g ) {
                my $pollid = $1;

                my $name = LJ::Poll->new($pollid)->name;
                if ( $name ) {
                    LJ::Poll->clean_poll(\$name);
                }
                else {
                    $name = "#$pollid";
                }

                $event =~ s!<lj-poll-$pollid>!<div><a href="$LJ::SITEROOT/poll/?id=$pollid">View Poll: $name</a></div>!g;
            }

            my %args = LJ::Request->args;
            LJ::EmbedModule->expand_entry($u, \$event, expand_full => 1)
                if %args && $args{'unfold_embed'};

            $ppid = $1
                if $event =~ m!<lj-phonepost journalid=[\'\"]\d+[\'\"] dpid=[\'\"](\d+)[\'\"]( /)?>!;
        }

        my $mood;

        if ( $entry_obj->prop('current_mood') ) {
            $mood = $entry_obj->prop('current_mood');
        }
        elsif ( $entry_obj->prop('current_moodid') ) {
            $mood = LJ::mood_name($entry_obj->prop('current_moodid') + 0);
        }

        my $alldateparts = $entry_obj->{'eventtime'};
        $alldateparts =~ s/[-:]/ /g;

        my $createtime = $LJ::EndOfTime - $entry_obj->{rlogtime};
        push @cleanitems, {
            entry      => $entry_obj,
            itemid     => $entry_obj->jitemid,
            ditemid    => $ditemid,
            subject    => $subject,
            event      => $event,
            createtime => $createtime,
            eventtime  => $alldateparts,
            modtime    => $entry_obj->prop('revtime') || $createtime,
            comments   => $entry_obj->comments_shown,
            music      => $entry_obj->prop('current_music'),
            mood       => $mood,
            ppid       => $ppid,
            tags       => [ values %{$logtags->{$entry_obj->jitemid} || {}} ],
            security   => $entry_obj->security,
            posterid   => $entry_obj->poster->id,
            replycount => $entry_obj->prop('replycount'),
            posteruser => $entry_obj->poster->user,
        };
    }

    # fix up the build date to use entry-time
    $journalinfo->{'builddate'} = LJ::TimeUtil->time_to_http($LJ::EndOfTime - $objs[0]->{'rlogtime'}),

    return $viewfunc->{handler}->($journalinfo, $u, $opts, \@cleanitems, \@objs);
}

# the creator for the RSS XML syndication view
sub create_view_rss {
    my ($journalinfo, $u, $opts, $cleanitems, $objs) = @_;
    my $ret;

    # For Yandex ( http://blogs.yandex.ru/faq.xml?id=542563 )
    # if 'copyright' tag contains 'noindex', this rss will not be indexed.
    my $copyright = $u->should_block_robots ? 'NOINDEX' : '';

    # header
    $ret .= "<?xml version='1.0' encoding='$opts->{'saycharset'}' ?>\n";
    $ret .= LJ::run_hook("bot_director", "<!-- ", " -->") . "\n";
    $ret .= "<rss version='2.0' xmlns:lj='http://www.livejournal.org/rss/lj/1.0/' " .
            "xmlns:media='http://search.yahoo.com/mrss/' " .
            "xmlns:atom10='http://www.w3.org/2005/Atom'>\n";

    # channel attributes
    $ret .= "<channel>\n";
    $ret .= "  <title>" . LJ::exml($journalinfo->{title}) . "</title>\n";
    $ret .= "  <link>$journalinfo->{link}</link>\n";
    $ret .= "  <description>" . LJ::exml("$journalinfo->{title} - $LJ::SITENAME") . "</description>\n";
    $ret .= "  <managingEditor>" . LJ::exml($journalinfo->{email}) . "</managingEditor>\n" if $journalinfo->{email};
    $ret .= "  <lastBuildDate>$journalinfo->{builddate}</lastBuildDate>\n";
    $ret .= "  <generator>LiveJournal / $LJ::SITENAME</generator>\n";
    $ret .= "  <lj:journal>" . $u->user . "</lj:journal>\n";
    $ret .= "  <lj:journalid>" . $u->userid . "</lj:journalid>\n";
    $ret .= "  <lj:journaltype>" . $u->journaltype_readable . "</lj:journaltype>\n";
    $ret .= "  <copyright>" . $copyright . "</copyright>\n" if $copyright;
    # TODO: add 'language' field when user.lang has more useful information

    unless ($LJ::DISABLED{'hubbub_discovery'}) {
        foreach my $hub (@LJ::HUBBUB_HUBS) {
            $ret .= "  <atom10:link rel='hub' href='" . LJ::exml($hub) . "' />\n";
        }
    }

    ### image block, returns info for their current userpic
    if ($u->{'defaultpicid'}) {
        my $pic = {};
        LJ::load_userpics($pic, [ $u, $u->{'defaultpicid'} ]);
        $pic = $pic->{$u->{'defaultpicid'}}; # flatten

        $ret .= "  <image>\n";
        $ret .= "    <url>$LJ::USERPIC_ROOT/$u->{'defaultpicid'}/$u->{'userid'}</url>\n";
        $ret .= "    <title>" . LJ::exml($journalinfo->{title}) . "</title>\n";
        $ret .= "    <link>$journalinfo->{link}</link>\n";
        $ret .= "    <width>$pic->{'width'}</width>\n";
        $ret .= "    <height>$pic->{'height'}</height>\n";
        $ret .= "  </image>\n\n";
    }

    # output individual item blocks
    foreach my $it (@$cleanitems) {
        my $entry = $it->{entry};
        my $itemid = $it->{itemid};
        my $ditemid = $it->{ditemid};
        my $url  = $entry->url;

        $ret .= "<item>\n";
        $ret .= "  <guid isPermaLink='true'>$url</guid>\n";
        $ret .= "  <pubDate>" . LJ::TimeUtil->time_to_http($it->{createtime}) . "</pubDate>\n";
        $ret .= "  <title>" . LJ::exml($it->{subject}) . "</title>\n" if $it->{subject};
        $ret .= "  <author>" . LJ::exml($journalinfo->{email}) . "</author>" if $journalinfo->{email};
        $ret .= "  <link>$url</link>\n";
        # omit the description tag if we're only syndicating titles
        #   note: the $event was also emptied earlier, in make_feed
        unless ($u->{'opt_synlevel'} eq 'title') {
            $ret .= "  <description>" . LJ::exml($it->{event}) . "</description>\n";
        }
        if ($it->{comments}) {
            $ret .= "  <comments>" . $entry->url . "</comments>\n";
        }
        $ret .= "  <category>$_</category>\n" foreach map { LJ::exml($_) } @{$it->{tags} || []};
        # support 'podcasting' enclosures
        $ret .= LJ::run_hook( "pp_rss_enclosure",
                { userid => $u->{userid}, ppid => $it->{ppid} }) if $it->{ppid};
        # TODO: add author field with posterid's email address, respect communities
        $ret .= "  <lj:music>" . LJ::exml($it->{music}) . "</lj:music>\n" if $it->{music};
        $ret .= "  <media:title type=\"plain\">" . LJ::exml($it->{music}) . "</media:title>\n" if $it->{music};
        $ret .= "  <lj:mood>" . LJ::exml($it->{mood}) . "</lj:mood>\n" if $it->{mood};
        $ret .= "  <lj:security>" . LJ::exml($it->{security}) . "</lj:security>\n" if $it->{security};
        unless ($u->{'userid'} == $it->{'posterid'}) {
            $ret .= "  <lj:poster>" . LJ::exml($it->{'posteruser'}) . "</lj:poster>\n";
            $ret .= "  <lj:posterid>" . $it->{'posterid'} . "</lj:posterid>\n";
        }
        $ret .= "  <lj:reply-count>$it->{replycount}</lj:reply-count>\n";

        if ($opts->{include_statistics}) {

            my $now = DateTime->now(time_zone => 'Europe/Moscow');
            my $yesterday = $now->clone->subtract(days => 1);

            # visitors
            my $data_v = LJ::PersonalStats::DB->fetch('post_stats', {
                            type        => 0, # post views only in journal
                            date        => $now->strftime("%Y-%m"),
                            journal_id  => $u->userid,
                            post_id     => $ditemid,
                            });
            # hits, today and yesterday
            my $data_t = LJ::PersonalStats::DB->fetch('post_stats', {
                            type        => 0, # post views only in journal
                            date        => $now->strftime("%Y-%m-%d"),
                            journal_id  => $u->userid,
                            post_id     => $ditemid,
                            });
            my $data_y = LJ::PersonalStats::DB->fetch('post_stats', {
                            type        => 0, # post views only in journal
                            date        => $yesterday->strftime("%Y-%m-%d"),
                            journal_id  => $u->userid,
                            post_id     => $ditemid,
                            });

            # sum last 24 hours: 00 to current hour and current hour + 1 to 23 in yesterday
            my $sum = 0;

            my @today_hits;
            foreach my $el (@$data_t) {
                $today_hits[ $el->{time_id} ] = $el->{hits};
            }

            for (my $i = 0; $i <= $now->hour; $i++) {
                $sum += $today_hits[$i];
            }

            if ($now->hour < 23) {
                my @yesterday_hits;
                foreach my $el (@$data_y) {
                    $yesterday_hits[ $el->{time_id} ] = $el->{hits};
                }

                for (my $i = $now->hour + 1; $i <= 23; $i++) {
                    $sum += $yesterday_hits[$i];
                }
            }

            $ret .= "<pageviews>$sum</pageviews>\n";

            my @day_visitors;
            foreach my $el (@$data_v) {
                $day_visitors[ $el->{time_id} ] = $el->{visitors};
            }
            my $today_visitors = $day_visitors[$now->day] || 0;

            $ret .= "<visitors>$today_visitors</visitors>\n";
        }

        $ret .= "</item>\n";
    }

    $ret .= "</channel>\n";
    $ret .= "</rss>\n";

    return $ret;
}


# the creator for the Atom view
# keys of $opts:
# single_entry - only output an <entry>..</entry> block. off by default
# apilinks - output AtomAPI links for posting a new entry or
#            getting/editing/deleting an existing one. off by default
# TODO: define and use an 'lj:' namespace
#
# TODO: Remove lines marked with 'COMPAT' - they are only present
# to allow backwards compatibility with atom parsers that are pre 0.6-draft.
# We create tags valid for 1.1-draft, but we want to be nice during
# atom's (and atom users) continuing transition.  1.0 parsers, according
# to spec, should NOT barf on unknown tags.
# * Where we can't be compatible, we use Atom 1.0. *
# http://www.ietf.org/internet-drafts/draft-ietf-atompub-format-11.txt
#
sub create_view_atom
{
    my ( $j, $u, $opts, $cleanitems, $entrylist ) = @_;
    my ( $feed, $xml, $ns );

    $ns = "http://www.w3.org/2005/Atom";

    # Strip namespace from child tags. Set default namespace, let
    # child tags inherit from it.  So ghetto that we even have to do this
    # and LibXML can't on its own.
    my $normalize_ns = sub {
        my $str = shift;
        $str =~ s/(<\w+)\s+xmlns="\Q$ns\E"/$1/og;
        $str =~ s/<feed\b/<feed xmlns="$ns" xmlns:lj="$LJ::SITEROOT"/;
        $str =~ s/<entry>/<entry xmlns="$ns" xmlns:lj="$LJ::SITEROOT">/ if $opts->{'single_entry'};
        return $str;
    };

    # AtomAPI interface path
    my $api = $opts->{'apilinks'} ? "$LJ::SITEROOT/interface/atom" :
                                    $u->journal_base . "/data/atom";

    my $make_link = sub {
        my ( $rel, $type, $href, $title ) = @_;
        my $link = XML::Atom::Link->new( Version => 1 );
        $link->rel($rel);
        $link->type($type) if $type;
        $link->href($href);
        $link->title( $title ) if $title;
        return $link;
    };

    my $author = XML::Atom::Person->new( Version => 1 );
    my $journalu = $j->{u};
    $author->email( $journalu->email_for_feeds ) if $journalu && $journalu->email_for_feeds;
    $author->name(  $u->{'name'} );

    # feed information
    unless ($opts->{'single_entry'}) {
        $feed = XML::Atom::Feed->new( Version => 1 );
        $xml  = $feed->{doc};

        unless ($xml){
            die "Error: XML-LibXML is required"; ## sudo yum install perl-XML-LibXML
        }

        if ($u->should_block_robots) {
            $xml->getDocumentElement->setAttribute( "xmlns:idx", "urn:atom-extension:indexing" );
            $xml->getDocumentElement->setAttribute( "idx:index", "no" );
        }

        $xml->insertBefore( $xml->createComment( LJ::run_hook("bot_director") ), $xml->documentElement());

        # attributes
        $feed->id( "urn:lj:$LJ::DOMAIN:atom1:$u->{user}" );
        $feed->title( $j->{'title'} || $u->{user} );
        if ( $j->{'subtitle'} ) {
            $feed->subtitle( $j->{'subtitle'} );
        }

        $feed->author( $author );
        $feed->add_link( $make_link->( 'alternate', 'text/html', $j->{'link'} ) );
        $feed->add_link(
            $make_link->(
                'self',
                $opts->{'apilinks'}
                ? ( 'application/x.atom+xml', "$api/feed" )
                : ( 'text/xml', $api )
            )
        );
        $feed->updated( LJ::TimeUtil->time_to_w3c($j->{'modtime'}, 'Z') );

        my $ljinfo = $xml->createElement( 'lj:journal' );
        $ljinfo->setAttribute( 'userid', $u->userid );
        $ljinfo->setAttribute( 'username', LJ::exml($u->user) );
        $ljinfo->setAttribute( 'type', LJ::exml($u->journaltype_readable) );
        $xml->getDocumentElement->appendChild( $ljinfo );

        # link to the AtomAPI version of this feed
        $feed->add_link(
            $make_link->(
                'service.feed',
                'application/x.atom+xml',
                ( $opts->{'apilinks'} ? "$api/feed" : $api ),
                $j->{'title'}
            )
        );

        $feed->add_link(
            $make_link->(
                'service.post',
                'application/x.atom+xml',
                "$api/post",
                'Create a new entry'
            )
        ) if $opts->{'apilinks'};

        unless ($LJ::DISABLED{'hubbub_discovery'}) {
            foreach my $hub (@LJ::HUBBUB_HUBS) {
                $feed->add_link($make_link->('hub', undef, $hub));
            }
        }
    }

    my $posteru = LJ::load_userids( map { $_->{posterid} } @$cleanitems);

    # output individual item blocks
    foreach my $it ( @$cleanitems ) {
        my $obj = $it->{entry};
        my $itemid = $it->{itemid};
        my $ditemid = $it->{ditemid};
        my $poster = $posteru->{$it->{posterid}};

        my $entry = XML::Atom::Entry->new( Version => 1 );
        my $entry_xml = $entry->{doc};

        $entry->id("urn:lj:$LJ::DOMAIN:atom1:$u->{user}:$ditemid");

        # author isn't required if it is in the main <feed>
        # only add author if we are in a single entry view, or
        # the journal entry isn't owned by the journal owner. (communities)
        if ( $opts->{'single_entry'} || $journalu->email_raw ne $poster->email_raw ) {
            my $author = XML::Atom::Person->new( Version => 1 );
            $author->email( $poster->email_visible ) if $poster->email_visible;
            $author->name(  $poster->{name} );
            $entry->author( $author );

            # and the lj-specific stuff
            my $postauthor = $entry_xml->createElement( 'lj:poster' );
            $postauthor->setAttribute( 'user', LJ::exml($poster->user));
            $postauthor->setAttribute( 'userid', $poster->userid);
            $entry_xml->getDocumentElement->appendChild( $postauthor );
        }

        $entry->add_link(
            $make_link->( 'alternate', 'text/html', $obj->url ) #"$j->{'link'}$ditemid.html" )
        );
        $entry->add_link(
            $make_link->( 'self', 'text/xml', "$api/?itemid=$ditemid" )
        );

        $entry->add_link(
            $make_link->(
                'service.edit',      'application/x.atom+xml',
                "$api/edit/$itemid", 'Edit this post'
            )
          ) if $opts->{'apilinks'};

        # NOTE: Atom 0.3 allowed for "issued", where we put the time the
        # user says it was. There's no equivalent in later versions of
        # Atom, though. And Atom 0.3 is deprecated. Oh well.

        my ($year, $mon, $mday, $hour, $min, $sec) = split(/ /, $it->{eventtime});
        my $event_date = sprintf("%04d-%02d-%02dT%02d:%02d:%02d",
                                 $year, $mon, $mday, $hour, $min, $sec);


        # title can't be blank and can't be absent, so we have to fake some subject
        $entry->title( $it->{'subject'} ||
                       "$journalu->{user} \@ $event_date"
                       );


        $entry->published( LJ::TimeUtil->time_to_w3c($it->{createtime}, "Z") );
        $entry->updated(   LJ::TimeUtil->time_to_w3c($it->{modtime},    "Z") );

        # XML::Atom 0.13 doesn't support categories.   Maybe later?
        foreach my $tag ( @{$it->{tags} || []} ) {
            $tag = LJ::exml( $tag );
            my $category = $entry_xml->createElement( 'category' );
            $category->setAttribute( 'term', $tag );
            $category->setNamespace( $ns );
            $entry_xml->getDocumentElement->appendChild( $category );
        }

        if ($it->{'music'}) {
            my $music = $entry_xml->createElement( 'lj:music' );
            $music->appendTextNode( $it->{'music'} );
            $entry_xml->getDocumentElement->appendChild( $music );
        }

        # if syndicating the complete entry
        #   -print a content tag
        # elsif syndicating summaries
        #   -print a summary tag
         # else (code omitted), we're syndicating title only
        #   -print neither (the title has already been printed)
        #   note: the $event was also emptied earlier, in make_feed
        #
        # a lack of a content element is allowed,  as long
        # as we maintain a proper 'alternate' link (above)
        my $make_content = sub {
            my $content = $entry_xml->createElement( $_[0] );
            $content->setAttribute( 'type', 'html' );
            $content->setNamespace( $ns );
            $content->appendTextNode( $it->{'event'} );
            $entry_xml->getDocumentElement->appendChild( $content );
        };
        if ($u->{'opt_synlevel'} eq 'full') {
            # Do this manually for now, until XML::Atom supports new
            # content type classifications.
            $make_content->('content');
        } elsif ($u->{'opt_synlevel'} eq 'summary') {
            $make_content->('summary');
        }

        if ( $opts->{'single_entry'} ) {
            return $normalize_ns->( $entry->as_xml() );
        }
        else {
            $feed->add_entry( $entry );
        }
    }

    return $normalize_ns->( $feed->as_xml() );
}

# create a FOAF page for a user
sub create_view_foaf {
    my ($journalinfo, $u, $opts) = @_;
    my $comm = ($u->{journaltype} eq 'C');

    my $ret;

    # return nothing if we're not a user
    unless ($u->{journaltype} eq 'P' || $comm) {
        $opts->{handler_return} = 404;
        return undef;
    }

    # set our content type
    $opts->{contenttype} = 'application/rdf+xml; charset=' . $opts->{saycharset};

    # setup userprops we will need
    LJ::load_user_props($u, qw{
        aolim icq yahoo jabber msn icbm url urlname external_foaf_url country city journaltitle
    });

    # create bare foaf document, for now
    $ret = "<?xml version='1.0'?>\n";
    $ret .= LJ::run_hook("bot_director", "<!-- ", " -->");
    $ret .= "<rdf:RDF\n";
    $ret .= "   xml:lang=\"en\"\n";
    $ret .= "   xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\n";
    $ret .= "   xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\"\n";
    $ret .= "   xmlns:foaf=\"http://xmlns.com/foaf/0.1/\"\n";
    $ret .= "   xmlns:ya=\"http://blogs.yandex.ru/schema/foaf/\"\n";
    $ret .= "   xmlns:lj=\"http://www.livejournal.org/rss/lj/1.0/\"\n";
    $ret .= "   xmlns:geo=\"http://www.w3.org/2003/01/geo/wgs84_pos#\"\n";
    $ret .= "   xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n";

    # precompute some values
    my $digest = "";
    if ($u->is_validated) {
        my $remote = LJ::get_remote();
        my $email_visible = $u->email_visible($remote);
        $digest = Digest::SHA1::sha1_hex("mailto:$email_visible") if $email_visible;
    }

    # channel attributes
    $ret .= ($comm ? "  <foaf:Group>\n" : "  <foaf:Person>\n");
    $ret .= "    <foaf:nick>$u->{user}</foaf:nick>\n";
    $ret .= "    <foaf:name>". LJ::exml($u->{name}) ."</foaf:name>\n";
    $ret .= "    <lj:journaltitle>". LJ::exml($u->{journaltitle}) ."</lj:journaltitle>\n" if $u->{journaltitle};
    $ret .= "    <lj:journalsubtitle>". LJ::exml($u->{journalsubtitle}) ."</lj:journalsubtitle>\n" if $u->{journalsubtitle};
    $ret .= "    <foaf:openid rdf:resource=\"" . $u->journal_base . "/\" />\n" unless $comm;

    # user location
    if ($u->{'country'}) {
        my $ecountry = LJ::eurl($u->{'country'});
        $ret .= "    <ya:country dc:title=\"$ecountry\" rdf:resource=\"$LJ::SITEROOT/directory.bml?opt_sort=ut&amp;s_loc=1&amp;loc_cn=$ecountry\"/>\n";
        if ($u->{'city'}) {
            my $estate = '';  # FIXME: add state.  Yandex didn't need it.
            my $ecity = LJ::eurl($u->{'city'});
            $ret .= "    <ya:city dc:title=\"$ecity\" rdf:resource=\"$LJ::SITEROOT/directory.bml?opt_sort=ut&amp;s_loc=1&amp;loc_cn=$ecountry&amp;loc_st=$estate&amp;loc_ci=$ecity\"/>\n";
       }
    }

    if ($u->{bdate} && $u->{bdate} ne "0000-00-00" && !$comm && $u->can_show_full_bday) {
        $ret .= "    <foaf:dateOfBirth>".$u->bday_string."</foaf:dateOfBirth>\n";
    }
    $ret .= "    <foaf:mbox_sha1sum>$digest</foaf:mbox_sha1sum>\n" if $digest;

    # userpic
    if (my $picid = $u->{'defaultpicid'}) {
        $ret .= "    <foaf:img rdf:resource=\"$LJ::USERPIC_ROOT/$picid/$u->{userid}\" />\n";
    }

    $ret .= "    <foaf:page>\n";
    $ret .= "      <foaf:Document rdf:about=\"" . $u->profile_url . "\">\n";
    $ret .= "        <dc:title>$LJ::SITENAME Profile</dc:title>\n";
    $ret .= "        <dc:description>Full $LJ::SITENAME profile, including information such as interests and bio.</dc:description>\n";
    $ret .= "      </foaf:Document>\n";
    $ret .= "    </foaf:page>\n";

    # we want to bail out if they have an external foaf file, because
    # we want them to be able to provide their own information.
    if ($u->{external_foaf_url}) {
        $ret .= "    <rdfs:seeAlso rdf:resource=\"" . LJ::eurl($u->{external_foaf_url}) . "\" />\n";
        $ret .= ($comm ? "  </foaf:Group>\n" : "  </foaf:Person>\n");
        $ret .= "</rdf:RDF>\n";
        return $ret;
    }

    # contact type information
    my %types = (
        aolim => 'aimChatID',
        icq => 'icqChatID',
        yahoo => 'yahooChatID',
        msn => 'msnChatID',
        jabber => 'jabberID',
    );
    if ($u->{allow_contactshow} eq 'Y') {
        foreach my $type (keys %types) {
            next unless defined $u->{$type};
            $ret .= "    <foaf:$types{$type}>" . LJ::exml($u->{$type}) . "</foaf:$types{$type}>\n";
        }
    }

    # blog activity
    {

        my $dbcr = LJ::get_cluster_reader($u);
        my $num_comments_received = $u->num_comments_received( dbh => $dbcr ) || 0;
        my $num_comments_posted   = $u->num_comments_posted( dbh => $dbcr ) || 0;

        my $count = $u->number_of_posts;
        $ret .= "    <ya:blogActivity>\n";
        $ret .= "      <ya:Posts>\n";
        $ret .= "        <ya:feed rdf:resource=\"" . LJ::journal_base($u) ."/data/rss\" dc:type=\"application/rss+xml\" />\n";
        $ret .= "        <ya:posted>$count</ya:posted>\n";
        $ret .= "      </ya:Posts>\n";
        $ret .= "      <ya:Comments>\n";
        ##### we are don't have rss feed for user's comments
        ####  $ret .= "        <ya:feed rdf:resource=\"recent comments rss\" dc:type=\"application/rss+xml\"/>\n";
        ###############
        $ret .= "        <ya:posted>$num_comments_posted</ya:posted>\n";
        $ret .= "        <ya:received>$num_comments_received</ya:received>\n";
        $ret .= "      </ya:Comments>\n";
        $ret .= "    </ya:blogActivity>\n";
    }

    # include a user's journal page and web site info
    my $time_create = ($u->timecreate) ? LJ::TimeUtil->time_to_w3c($u->timecreate) : '';
    my $time_update = ($u->timeupdate) ? LJ::TimeUtil->time_to_w3c($u->timeupdate) : '';
    $ret .= "    <foaf:weblog rdf:resource='" . LJ::journal_base($u) . "/'";
    $ret .= " lj:dateCreated='$time_create'" if $time_create;
    $ret .= " lj:dateLastUpdated='$time_update'" if $time_update;
    $ret .= " />\n";
    if ($u->{url}) {
        $ret .= "    <foaf:homepage rdf:resource=\"" . LJ::eurl($u->{url});
        $ret .= "\" dc:title=\"" . LJ::exml($u->{urlname}) . "\" />\n";
    }

    # user bio
    if ($u->{'has_bio'} eq "Y") {
        $u->{'bio'} = LJ::get_bio($u);
        LJ::text_out(\$u->{'bio'});
        LJ::CleanHTML::clean_userbio(\$u->{'bio'});
        $ret .= "    <ya:bio>" . LJ::exml($u->{'bio'}) . "</ya:bio>\n";
    }

    # user schools
    if ($u->{'journaltype'} ne 'Y' &&
        !$LJ::DISABLED{'schools'}  &&
        ($u->{'opt_showschools'} eq '' || $u->{'opt_showschools'} eq 'Y')) {

        my $schools = LJ::Schools::get_attended($u);
        if ($u->{'journaltype'} ne 'C' && $schools && %$schools ) {
             my @links;
             foreach my $sid (sort { $schools->{$a}->{year_start} <=> $schools->{$b}->{year_start} } keys %$schools) {
                 my $link = "$LJ::SITEROOT/schools/" .
                     "?ctc=" . LJ::eurl($schools->{$sid}->{country}) .
                     "&sc=" . LJ::eurl($schools->{$sid}->{state}) .
                     "&cc=" . LJ::eurl($schools->{$sid}->{city}) .
                     "&sid=" . $sid ;
                 my $ename = LJ::ehtml($schools->{$sid}->{name});
                 $ret .= "    <ya:school\n";
                 $ret .= "       rdf:resource=\"" . LJ::exml($link) . "\"\n";
                 if (defined $schools->{$sid}->{year_start}) {
                     $ret .= "       ya:dateStart=\"$schools->{$sid}->{year_start}\"\n";
                 }
                 if (defined $schools->{$sid}->{year_end}) {
                     $ret .= "       ya:dateFinish=\"$schools->{$sid}->{year_end}\"\n";
                 }

                 $ret .= "       dc:title=\"$ename\"/>\n";
             }
         }
    }

    # icbm/location info
    if ($u->{icbm}) {
        my @loc = split(",", $u->{icbm});
        $ret .= "    <foaf:based_near><geo:Point geo:lat='" . $loc[0] . "'" .
                " geo:long='" . $loc[1] . "' /></foaf:based_near>\n";
    }

    # interests, please!
    # arrayref of interests rows: [ intid, intname, intcount ]
    my $intu = LJ::get_interests($u);
    foreach my $int (@$intu) {
        LJ::text_out(\$int->[1]); # 1==interest
        $ret .= "    <foaf:interest dc:title=\"". LJ::exml($int->[1]) . "\" " .
                "rdf:resource=\"$LJ::SITEROOT/interests.bml?int=" . LJ::eurl($int->[1]) . "\" />\n";
    }

    # check if the user has a "FOAF-knows" group
    my $groups = LJ::get_friend_group($u->{userid}, { name => 'FOAF-knows' });
    my $mask = $groups ? 1 << $groups->{groupnum} : 0;

    # now information on who you know, limited to a certain maximum number of users
    my $friends = LJ::get_friends($u->{userid}, $mask);
    my @ids = keys %$friends;
    @ids = splice(@ids, 0, $LJ::MAX_FOAF_FRIENDS) if @ids > $LJ::MAX_FOAF_FRIENDS;

    # now load
    my %users;
    LJ::load_userids_multiple([ map { $_, \$users{$_} } @ids ], [$u]);

    # iterate to create data structure
    foreach my $friendid (@ids) {
        next if $friendid == $u->{userid};
        my $fu = $users{$friendid};
        next if $fu->{statusvis} =~ /[DXS]/ || $fu->{journaltype} ne 'P';

        my $name = LJ::exml($fu->name_raw);
        my $tagline = LJ::exml($fu->prop('journaltitle') || '');
        my $upicurl = $fu->userpic ? $fu->userpic->url : '';

        $ret .= $comm ? "    <foaf:member>\n" : "    <foaf:knows>\n";
        $ret .= "      <foaf:Person>\n";
        $ret .= "        <foaf:nick>$fu->{'user'}</foaf:nick>\n";
        $ret .= "        <foaf:member_name>$name</foaf:member_name>\n";
        $ret .= "        <foaf:tagLine>$tagline</foaf:tagLine>\n";
        $ret .= "        <foaf:image>$upicurl</foaf:image>\n" if $upicurl;
        $ret .= "        <rdfs:seeAlso rdf:resource=\"" . LJ::journal_base($fu) ."/data/foaf\" />\n";
        $ret .= "        <foaf:weblog rdf:resource=\"" . LJ::journal_base($fu) . "/\"/>\n";
        $ret .= "      </foaf:Person>\n";
        $ret .= $comm ? "    </foaf:member>\n" : "    </foaf:knows>\n";
    }

    # finish off the document
    $ret .= $comm ? "    </foaf:Group>\n" : "  </foaf:Person>\n";
    $ret .= "</rdf:RDF>\n";

    return $ret;
}

# YADIS capability discovery
sub create_view_yadis {
    my ($journalinfo, $u, $opts) = @_;
    my $person = ($u->{journaltype} eq 'P');

    my $ret = "";

    my $println = sub { $ret .= $_[0]."\n"; };

    $println->('<?xml version="1.0" encoding="UTF-8"?>');
    $println->('<xrds:XRDS xmlns:xrds="xri://$xrds" xmlns="xri://$xrd*($v*2.0)"><XRD>');

    local $1;
    $opts->{pathextra} =~ m!^(/.*)?$!;
    my $viewchunk = $1;

    my $view;
    if ($viewchunk eq '') {
        $view = "recent";
    }
    elsif ($viewchunk eq '/friends') {
        $view = "friends";
    }
    else {
        $view = undef;
    }

    if ($view eq 'recent') {
        # Only people (not communities, etc) can be OpenID authenticated
        if ($person && LJ::OpenID->server_enabled) {
            $println->('    <Service priority="0">');
            $println->('        <Type>http://specs.openid.net/auth/2.0/signon</Type>');
            $println->('        <URI>'.LJ::ehtml($LJ::OPENID_SERVER).'</URI>');
            $println->('        <LocalID>'.LJ::ehtml($u->journal_base) . '/' .'</LocalID>');
            $println->('    </Service>');
        }
    }
    elsif ($view eq 'friends') {
        $println->('    <Service xmlns:gm="http://openid.net/xmlns/groupmembership/xrds">');
        $println->('        <Type>http://openid.net/xmlns/groupmembership</Type>');
        $println->('        <URI>'.LJ::exml($LJ::SITEROOT).'/openid/groupmembership.bml</URI>');
        $println->('        <LocalID>'.LJ::exml($u->journal_base.'/friends').'</LocalID>');
        $println->('        <gm:CanEnumerate /><gm:CanQuery />');
        $println->('    </Service>');
    }

    # Local site-specific content
    # TODO: Give these hooks access to $view somehow?
    LJ::run_hook("yadis_service_descriptors", \$ret);

    $println->('</XRD></xrds:XRDS>');
    return $ret;
}

# create a userpic page for a user
sub create_view_userpics {
    my ($journalinfo, $u, $opts) = @_;
    my ( $feed, $xml, $ns );

    $ns = "http://www.w3.org/2005/Atom";

    my $normalize_ns = sub {
        my $str = shift;
        $str =~ s/(<\w+)\s+xmlns="\Q$ns\E"/$1/og;
        $str =~ s/<feed\b/<feed xmlns="$ns"/;
        return $str;
    };

    my $make_link = sub {
        my ( $rel, $type, $href, $title ) = @_;
        my $link = XML::Atom::Link->new( Version => 1 );
        $link->rel($rel);
        $link->type($type);
        $link->href($href);
        $link->title( $title ) if $title;
        return $link;
    };

    my $author = XML::Atom::Person->new( Version => 1 );
    $author->name(  $u->{name} );

    $feed = XML::Atom::Feed->new( Version => 1 );
    $xml  = $feed->{doc};

    if ($u->should_block_robots) {
        $xml->getDocumentElement->setAttribute( "xmlns:idx", "urn:atom-extension:indexing" );
        $xml->getDocumentElement->setAttribute( "idx:index", "no" );
    }

    my $bot = LJ::run_hook("bot_director");
    $xml->insertBefore( $xml->createComment( $bot ), $xml->documentElement())
        if $bot;

    $feed->id( "urn:lj:$LJ::DOMAIN:atom1:$u->{user}:userpics" );
    $feed->title( "$u->{user}'s userpics" );

    $feed->author( $author );
    $feed->add_link( $make_link->( 'alternate', 'text/html', "$LJ::SITEROOT/allpics.bml?user=$u->{user}" ) );
    $feed->add_link( $make_link->( 'self', 'text/xml', $u->journal_base() . "/data/userpics" ) );

    # now start building all the userpic data
    # start up by loading all of our userpic information and creating that part of the feed
    my $info = LJ::get_userpic_info($u, {'load_comments' => 1, 'load_urls' => 1});

    my %keywords = ();
    while (my ($kw, $pic) = each %{$info->{kw}}) {
        LJ::text_out(\$kw);
        push @{$keywords{$pic->{picid}}}, LJ::ehtml($kw);
    }

    my %comments = ();
    while (my ($pic, $comment) = each %{$info->{comment}}) {
        LJ::text_out(\$comment);
        $comments{$pic} = LJ::ehtml($comment);
    }

    my @pics;
    push @pics, map { $info->{pic}->{$_} } sort { $a <=> $b }
                      grep { $info->{pic}->{$_}->{state} eq 'N' } keys %{$info->{pic}};

    my $entry;
    my %picdata;

    # this is lame, but we have to do this iteration twice; we load the userpic data first, so that
    # we can figure out what the most recently-uploaded userpic is. we need to put that into the feed
    # before any of the <entry> values.

    my $latest = 0;
    foreach my $pic (@pics) {
        LJ::load_userpics(\%picdata, [$u, $pic->{picid}] );
        $latest = ($latest < $picdata{$pic->{picid}}->{picdate}) ? $picdata{$pic->{picid}}->{picdate} : $latest;
    }

    $feed->updated( LJ::TimeUtil->time_to_w3c($latest, 'Z') );

    foreach my $pic (@pics) {
        my $entry = XML::Atom::Entry->new( Version => 1 );
        my $entry_xml = $entry->{doc};

        $entry->id("urn:lj:$LJ::DOMAIN:atom1:$u->{user}:userpics:$pic->{picid}");

        my $title = ($pic->{picid} == $u->{defaultpicid}) ? "default userpic" : "userpic";
        $entry->title( $title );

        $entry->updated( LJ::TimeUtil->time_to_w3c($picdata{$pic->{picid}}->{picdate}, 'Z') );

        my $content;
        $content = $entry_xml->createElement( "content" );
        $content->setAttribute( 'src', "$LJ::USERPIC_ROOT/$pic->{picid}/$u->{userid}" );
        $content->setNamespace( $ns );
        $entry_xml->getDocumentElement->appendChild( $content );

        foreach my $kw (@{$keywords{$pic->{picid}}}) {
            my $ekw = LJ::exml( $kw );
            my $category = $entry_xml->createElement( 'category' );
            $category->setAttribute( 'term', $ekw );
            $category->setNamespace( $ns );
            $entry_xml->getDocumentElement->appendChild( $category );
        }

        if($comments{$pic->{picid}}) {
            my $content = $entry_xml->createElement( "summary" );
            $content->setNamespace( $ns );
            $content->appendTextNode( $comments{$pic->{picid}} );
            $entry_xml->getDocumentElement->appendChild( $content );
        };

        $feed->add_entry( $entry );
    }

    return $normalize_ns->( $feed->as_xml() );
}


sub create_view_comments
{
    my ($journalinfo, $u, $opts) = @_;

    if (LJ::conf_test($LJ::DISABLED{latest_comments_rss}, $u)) {
        $opts->{handler_return} = 404;
        return 404;
    }

    unless ($u->get_cap('latest_comments_rss')) {
        $opts->{handler_return} = 403;
        return;
    }

    my $ret;
    $ret .= "<?xml version='1.0' encoding='$opts->{'saycharset'}' ?>\n";
    $ret .= LJ::run_hook("bot_director", "<!-- ", " -->") . "\n";
    $ret .= "<rss version='2.0' xmlns:lj='http://www.livejournal.org/rss/lj/1.0/'>\n";

    # channel attributes
    $ret .= "<channel>\n";
    $ret .= "  <title>" . LJ::exml($journalinfo->{title}) . "</title>\n";
    $ret .= "  <link>$journalinfo->{link}</link>\n";
    $ret .= "  <description>Latest comments in " . LJ::exml($journalinfo->{title}) . "</description>\n";
    $ret .= "  <managingEditor>" . LJ::exml($journalinfo->{email}) . "</managingEditor>\n" if $journalinfo->{email};
    $ret .= "  <lastBuildDate>$journalinfo->{builddate}</lastBuildDate>\n";
    $ret .= "  <generator>LiveJournal / $LJ::SITENAME</generator>\n";
    $ret .= "  <lj:journal>" . $u->user . "</lj:journal>\n";
    $ret .= "  <lj:journaltype>" . $u->journaltype_readable . "</lj:journaltype>\n";
    # TODO: add 'language' field when user.lang has more useful information

    ### image block, returns info for their current userpic
    if ($u->{'defaultpicid'}) {
        my $pic = {};
        LJ::load_userpics($pic, [ $u, $u->{'defaultpicid'} ]);
        $pic = $pic->{$u->{'defaultpicid'}}; # flatten

        $ret .= "  <image>\n";
        $ret .= "    <url>$LJ::USERPIC_ROOT/$u->{'defaultpicid'}/$u->{'userid'}</url>\n";
        $ret .= "    <title>" . LJ::exml($journalinfo->{title}) . "</title>\n";
        $ret .= "    <link>$journalinfo->{link}</link>\n";
        $ret .= "    <width>$pic->{'width'}</width>\n";
        $ret .= "    <height>$pic->{'height'}</height>\n";
        $ret .= "  </image>\n\n";
    }

    my @comments = $u->get_recent_talkitems(25);
    foreach my $r (@comments)
    {
        my $c = LJ::Comment->new($u, jtalkid => $r->{jtalkid});
        my $thread_url = $c->thread_url;
        my $subject = $c->subject_raw;
        LJ::CleanHTML::clean_subject_all(\$subject);

        $ret .= "<item>\n";
        $ret .= "  <guid isPermaLink='true'>$thread_url</guid>\n";
        $ret .= "  <pubDate>" . LJ::TimeUtil->time_to_http($r->{datepostunix}) . "</pubDate>\n";
        $ret .= "  <title>" . LJ::exml($subject) . "</title>\n" if $subject;
        $ret .= "  <link>$thread_url</link>\n";
        # omit the description tag if we're only syndicating titles
        unless ($u->{'opt_synlevel'} eq 'title') {
            my $body = $c->body_raw;
            LJ::CleanHTML::clean_subject_all(\$body);
            $ret .= "  <description>" . LJ::exml($body) . "</description>\n";
        }
        $ret .= "</item>\n";
    }

    $ret .= "</channel>\n";
    $ret .= "</rss>\n";


    return $ret;
}

sub generate_hubbub_jobs {
    my $u = shift;
    my $joblist = shift;

    return if $LJ::DISABLED{'hubbub'};

    foreach my $hub (@LJ::HUBBUB_HUBS) {
        my $make_hubbub_job = sub {
            my $type = shift;

            my $topic_url = $u->journal_base . "/data/$type";
            return TheSchwartz::Job->new(
                funcname => 'TheSchwartz::Worker::PubSubHubbubPublish',
                arg => {
                    hub => $hub,
                    topic_url => $topic_url,
                },
                coalesce => $hub,
            );
        };

        push @$joblist, $make_hubbub_job->("rss");
        push @$joblist, $make_hubbub_job->("atom");
    }
}


1;
