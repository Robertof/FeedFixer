#!/usr/bin/env perl
# Robertof's FFixer AndroidWorld Module
# Written by: Robertof
# Under: GNU/GPL v3
# Please load this module in the main program.
# You can configure various options in the 'new' method.

package FeedFixer::androidworld;
use strict;
use warnings;
use FeedFixer::Utils ':all'; # export constants
use Digest::MD5 qw(md5_hex);
use File::Spec;
use FeedFixer::RobParser;
use XML::FeedPP;

use constant {
    BLACKLIST => 0,
    WHITELIST => 1
};

my $imported = 0;

sub new
{
    main::printAndLog ("[AndroidWorld Plugin] AW Plugin initialized.");
    # -- configuration begin --
    ############################
    # HTML Tags Options        #
    # Specify which tags to    #
    # enable or disable here.  #
    ############################
    # Use blacklisting or whitelisting method?
    # Choose between WHITELIST and BLACKLIST (case sensitive)
    my $tag_preferred_method = WHITELIST;
    # Select allowed/disabled tags (depends if you are using BLIST/WLIST)
    my $tag_list             = [
        "img", # Images
        "b", "strong", "s", "strike", "em", "i", "u", # Markup tags
        "h1", "h2", "h3", # Headers
        "a",              # Links (recommended)
        "ul", "li",       # Lists (recommended)
        # Various tags
        # DON'T remove those if don't wanna run into problems.
        "blockquote", "code", "pre", "p", "div", "span", "br"
    ];
    ############################
    # Misc options             #
    # Miscellaneous options    #
    ############################
    # Original site feed. You don't wanna change this.
    my $misc_origFeed  = "http://www.androidworld.it/feed/";
    # Maximum number of articles. Do not set this to a too high number.
    my $misc_artNum    = 15;
    # Threshold for every request. By default it is set to 3 seconds, I
    # recommend this interval.
    # Please note: setting a too high threshold will require more time to
    # parse the feed, so other plugins will hang to run (they'll run only
    # when the previous plugin finished)
    my $misc_threshold = 1.5;
    # Cache directory. It MUST be writable. If it does not exist,
    # it'll be created.
    my $misc_cachedir  = "cache/";
    # Cache expiration. I recommend an high value, as articles aren't update
    # that much. 60 minutes, for example, is enough.
    my $misc_cache_exp = 60 * 60; # in seconds, as always
    # -- configuration ends here --
    # DO NOT CHANGE ANYTHING FROM THE FOLLOWING LINES.
    # create cache directory
    if (!-d $misc_cachedir)
    {
        eval { unlink "${misc_cachedir}"; };
        mkdir "${misc_cachedir}";
    }
    # set options in a nice hash
    my $realOpts = {
        "tag_method" => $tag_preferred_method,
        "tag_list"   => $tag_list,
        "misc_feed"  => $misc_origFeed,
        "misc_artNum"=> $misc_artNum,
        "misc_thold" => $misc_threshold,
        "misc_cdir"  => $misc_cachedir,
        "misc_cexp"  => $misc_cache_exp
    };
    # bless everything and return
    bless $realOpts, $_[0];
    return $realOpts;
}

# main subroutine, which should:
# - get the original feed
# - parse it
# - get the text for EACH article in it
# - remove blacklisted tags
# - return the text
sub getFeed
{
    # let the fun begin
    my $self = shift;
    $self->lp (sprintf ("'getFeed' subroutine called. Fetching main feed (%s)",
               $self->{misc_feed}));
    # first step: get the original feed
    # do HTTP request
    my $req = FeedFixer::Utils->do_http_get_request (
        $self->{"misc_feed"},
        NO_COOKIES,
        UA_MOZILLA_FIREFOX
    );
    if ($req eq REQ_FAILED)
    {
        FeedFixer::Utils->w ("Request to androidworld.it failed. Stopping.");
        return -1;
    }
    my @links;
    # read XML
    my $rss = XML::FeedPP->new ($req->[2]);
    #$rss->load ($req->[2]);
    my @items = $rss->get_item();
    my $count = scalar ( @items );
    if ($count <= 0)
    {
        FeedFixer::Utils->w ("No articles found. Stopping.");
        return -1;
    }
    $self->lp (sprintf ("Found %d articles. (limit: %d)", $count, $self->{"misc_artNum"}));
    # okay, now we have the items' link.
    # to avoid too many requests, a time-controlled cache is necessary.
    # brief explanation of the time controlled cache:
    # - from the pathname of the url it is generated an unique key
    # - the current UNIX time is appended at the end of the filename
    # - the script then checks if:
    #  > there is a cache file with the article's key
    #  > checks its time, if it's expired (now - that time >= 600 for example)
    #    redownload the article again, otherwise load from the cache
    # - looks nice, uh?
    # ------
    # okay, so, here we go.
    my $downloaded_last_time = 0; # threshold value
    my $iterated = 0;
    foreach my $rss_item (@items)
    {
        # generate unique key from that URL.
        my $alink = $rss_item->{"guid"}->{"#text"};
        # bad hack to enforce misc_artNum articles
        if ($iterated++ >= $self->{"misc_artNum"})
        {
            $rss->remove_item ($rss_item->{"link"});
            next;
        }
        my $key = md5_hex ($alink);
        $self->lp ("Parsing cache for link ${alink} (key: ${key})..");
        # check the cache, remove old elements, verify if we
        # have already an article with that key.
        my $cachefile = $self->find_cache_file ($key);
        my $art_text;
        if ($cachefile eq -1)
        {
            # cache file doesn't exist, download article from
            # remote link 
            $self->lp ("Cache file not found for ${alink}, downloading article..");
            if ($downloaded_last_time)
            {
                $self->lp (sprintf ("Waiting %d seconds..", $self->{"misc_thold"}));
                sleep ($self->{"misc_thold"});
            }
            my $req = FeedFixer::Utils->do_http_get_request ($alink, NO_COOKIES, UA_MOZILLA_FIREFOX);
            if ($req eq REQ_FAILED)
            {
                FeedFixer::Utils->w ("Request to androidworld.it failed, stopping.");
                return -1;
            }
            # create cache entry
            my $fname = File::Spec->catfile ($self->{"misc_cdir"}, "${key}-" . time() . ".cache");
            open FPA, ">", $fname or
                (FeedFixer::Utils->wrap (FeedFixer::Utils->w (
                    "Cannot open ${fname} for writing: ${!}, stopping"
                )) && return -1);
            print FPA $req->[2];
            close FPA;
            $self->lp ("Cache file ${fname} written successfully");
            $self->lp ("Article downloaded, waiting for text-cleaning..");
            $art_text = $req->[2];
            $downloaded_last_time = 1;
        }
        else
        {
            # found valid cachefile
            $cachefile =~ /[^-]+-(\d+)\.cache$/;
            $self->lp ("Found valid cache file for ${alink}, expires in " . 
                ( ( $self->{"misc_cexp"} / 60 ) - int ( ( ( time() - $1 ) / 60 ) + 0.5 ) ) . " minutes");
            # read cache file
            open FP, "<", $cachefile;
            $art_text .= $_ while (<FP>);
            close FP;
            $downloaded_last_time = 0;
        }
        # $art_text now contains HTML page text, we should now parse it!
        # initialize parser
        my $rp = FeedFixer::RobParser->new;
        $rp->clear(); # needed, otherwise bad things happens
        $rp->set_tag_stuff ($self->{"tag_method"}, $self->{"tag_list"});
        $rp->parse ($art_text);
        $rp->eof;
        # now we have article's fixed text, we just need to call..
        my $final_text = $rp->get_final_text;
        $self->lp ("Text parsed, pushing changes to the feed..");
        $rss_item->{"content:encoded"} = $final_text;
        $art_text = "";
    }
    # FINISH!
    # just return
    return $rss->to_string (indent => 4);
}

sub find_cache_file
{
    my ($self, $key) = @_;
    # get cache dir file listing
    opendir my $dir, $self->{"misc_cdir"} or FeedFixer::Utils->d (
        "Cannot open cache directory, error: ${!}"
    );
    my @files = readdir $dir;
    closedir $dir;
    return -1 if (scalar (@files) <= 0);
    # loop for every file
    my $kfound = -1;
    foreach (@files)
    {
        # check if some filenames are expired, also check if we found
        # the cachefile with our key
        if ($_ =~ /^([^\-]+)-(\d+)\.cache$/)
        {
            # check if this filename is expired
            my ($fkey, $ftime) = ($1, $2);
            if ( ( time - $ftime ) >= $self->{"misc_cexp"} )
            {
                # expired
                # unlink the file
                unlink File::Spec->catfile ($self->{"misc_cdir"}, "${fkey}-${ftime}.cache");
                $self->l ("Cache file ${fkey}-${ftime}.cache expired, deleting.");
                # go to the next iteration
                next;
            }
        }
        if ($_ =~ /^${key}-(\d+)\.cache$/)
        {
            # found key file, set in $kfound var
            # security check
            if ($kfound != -1)
            {
                FeedFixer::Utils->w ("Duplicate key: ${key}. Please check " . $self->{"misc_cdir"});
            }
            $kfound = File::Spec->catfile ($self->{"misc_cdir"}, "${key}-${1}.cache");
            # don't stop foreach, as other files may be expired
        }
    }
    return $kfound;
}

sub l
{
    # shorthand for log of main
    main::justLog ("[AndroidWorld Plugin] " . $_[1]);
}

sub p
{
    # shorthand for print of main
    main::justPrint ("[AndroidWorld Plugin] " . $_[1]);
}

sub lp
{
    # shorthand for print and log of main
    main::printAndLog ("[AndroidWorld Plugin] " . $_[1]);
}
1;
